/**
 * Copyright 2016 Google Inc. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const logging = require('@google-cloud/logging')();
const download = require('image-downloader')
const stripe = require('stripe')(functions.config().stripe.token);
stripe.setApiVersion('2019-02-19');
const currency = functions.config().stripe.currency || 'GBP';
var id;

// [START chargecustomer]
// Charge the Stripe customer whenever an amount is written to the Realtime database
exports.createStripeCharge = functions.database.ref('/stripe_customers/{userId}/charges/{id}')
    .onCreate((snap, context) => {
      const val = snap.val();
      // Look up the Stripe customer id written in createStripeCustomer
      return admin.database().ref(`/stripe_customers/${context.params.userId}/customer_id`)
          .once('value').then((snapshot) => {
            return snapshot.val();
          }).then((customer) => {
            // Create a charge using the pushId as the idempotency key
            // protecting against double charges
            const amount = val.amount;
            const idempotencyKey = context.params.id;
            const charge = {amount, currency, customer};
            if (val.source !== null) {
              charge.source = val.source;
            }
            return stripe.charges.create(charge, {idempotency_key: idempotencyKey});
          }).then((response) => {
            // If the result is successful, write it back to the database
            return snap.ref.set(response);
          }).catch((error) => {
            // We want to capture errors and render them in a user-friendly way, while
            // still logging an exception with StackDriver
            return snap.ref.child('error').set(userFacingMessage(error));
          }).then(() => {
            return reportError(error, {user: context.params.userId});
          });
        });
// [END chargecustomer]]

exports.createEphemeralKeys = functions.database
    .ref('/stripe_customers/{userId}/ephemeral_keys/api_version').onWrite((change, context) => {
      const source = change.after.val();
      if (source === null){
        return null;
      }
      return admin.database().ref(`/stripe_customers/${context.params.userId}/customer_id`)
          .once('value').then((snapshot) => {
            return snapshot.val();
          }).then((customer) => {
            console.log(source);
            console.log(source.api_version);
            return stripe.ephemeralKeys.create({
              customer: customer
            }, {
              stripe_version: source
            });
          }).then((response) => {
            return change.after.ref.parent.set(response);
          }, (error) => {
            return change.after.ref.parent.child('error').set(userFacingMessage(error));
          })
});

// When a user is created, register them with Stripe
exports.createStripeCustomer = functions.auth.user().onCreate((user) => {
  return stripe.accounts.create({
    type: 'custom',
    country: 'GB',
    business_type: 'individual',
    email: user.email,
  }).then((customer) => {
    return admin.database().ref(`/stripe_customers/${user.uid}/customer_id`).set(customer.id);
  });
});

exports.createStripeAccount = functions.auth.user().onCreate((user) => {
  return stripe.accounts.create({
    type: 'custom',
    country: 'GB',
    business_type: 'individual',
    email: user.email,
  }).then((customer) => {
    return admin.database().ref(`/stripe_customers/${user.uid}/customer_id`).set(customer.id);
  });
});

// Update a user's account so that they can receive Connect payments
exports.updateStripeCustomer = functions.database.ref('/stripe_customers/{userId}/info').onCreate((snap, context) => {
    const val = snap.val();

    return admin.database().ref(`/stripe_customers/${context.params.userId}/customer_id`)
      .once('value').then((snapshot) => {
        return snapshot.val();
      }).then((customer) => {
        return stripe.accounts.update(customer, {
          tos_acceptance: {
            date: Math.floor((new Date()).getTime() / 1000),
            ip: val.ip
          },
          individual: {
            address: {
              country: val.address_country,
              line1: val.address_line1,
              line2: val.address_line2,
              city: val.address_city,
              state: val.address_state,
              postal_code: val.address_postcode
            },
            dob: {
              day: val.dob_day,
              month: val.dob_month,
              year: val.dob_year
            },
            first_name: val.first_name,
            last_name: val.last_name,
            verification: {
              document: {
                front: val.identity_document
              }
            }
          },
          external_account: {
            object: 'bank_account',
            country: 'GB',
            currency: 'gbp',
            sort_code: val.sort_code,
            account_number: val.account_number,
            account_holder_name: val.first_name + " " + val.last_name,
            account_holder_type: 'individual'
          },
        })
        // return stripe.customers.createSource(customer, {source});
      }).then((response) => {
        return admin.database().ref(`/stripe_customers/${context.params.userId}/info`).set(response);
      }, (error) => {
        return reportError(error, {user: context.params.userId});
      })
});

// Manually create a Stripe customer for existing accounts, not used in release
exports.manuallyCreateStripeCustomer = functions.database.ref('/manual_stripe_create/{userId}').onCreate((snap, context) => {
    const val = snap.val()
    return stripe.accounts.create({
        type: 'custom',
        country: 'GB',
        business_type: 'individual',
        email: val.email,
  }).then((customer) => {
    return admin.database().ref(`/stripe_customers/${snap.key}/customer_id`).set(customer.id);
  });
});

// Add a payment source (card) for a user by writing a stripe payment source token to Realtime database
exports.addPaymentSource = functions.database
    .ref('/stripe_customers/{userId}/sources/{pushId}/token').onWrite((change, context) => {
      const source = change.after.val();
      if (source === null){
        return null;
      }
      return admin.database().ref(`/stripe_customers/${context.params.userId}/customer_id`)
          .once('value').then((snapshot) => {
            return snapshot.val();
          }).then((customer) => {
            return stripe.customers.createSource(customer, {source});
          }).then((response) => {
            return change.after.ref.parent.set(response);
          }, (error) => {
            return change.after.ref.parent.child('error').set(userFacingMessage(error));
          })
});

// .then(() => {
// return reportError(error, {user: context.params.userId});
// });

// When a user deletes their account, clean up after them
exports.cleanupUser = functions.auth.user().onDelete((user) => {
  return admin.database().ref(`/stripe_customers/${user.uid}`).once('value').then(
      (snapshot) => {
        return snapshot.val();
      }).then((customer) => {
        return stripe.customers.del(customer.customer_id);
      }).then(() => {
        return admin.database().ref(`/stripe_customers/${user.uid}`).remove();
      });
    });

// Delete a user's card
exports.deletePaymentSource = functions.database
    .ref('/stripe_customers/{userId}/sources/{pushId}/deleted').onWrite((change, context) => {
      const source = change.after.val();
      if (source === null){
        return null;
      }

      change.after.ref.parent.once("value", (snapshot) => {
        id = snapshot.val().id;
        console.log(id);
      });

      return admin.database().ref(`/stripe_customers/${context.params.userId}/customer_id`)
          .once('value').then((snapshot) => {
            return snapshot.val();
          }).then((customer) => {
            
            while (typeof id === 'undefined') {
                // Wait...
            }

            return stripe.customers.deleteCard(customer, id);
          }).then((response) => {
            return change.after.ref.parent.remove()
          }, (error) => {
            return change.after.ref.parent.child('error').set(userFacingMessage(error));
          });
        });

// Remove a user's bank account
exports.deleteBankAccount = functions.database
    .ref('/stripe_customers/{userId}/info/external_account/data/{pushId}/deleted').onWrite((change, context) => {
      const source = change.after.val();
      if (source === null){
        return null;
      }

      change.after.ref.parent.once("value", (snapshot) => {
        id = snapshot.val().id;
        console.log(id);
      });

      return admin.database().ref(`/stripe_customers/${context.params.userId}/customer_id`)
          .once('value').then((snapshot) => {
            return snapshot.val();
          }).then((customer) => {
            
            while (typeof id === 'undefined') {
                // Wait...
            }

            return stripe.customers.deleteSource(customer, id);
          }).then((response) => {
            return change.after.ref.parent.remove()
          }, (error) => {
            return change.after.ref.parent.child('error').set(userFacingMessage(error));
          });
        });

// To keep on top of errors, we should raise a verbose error report with Stackdriver rather
// than simply relying on console.error. This will calculate users affected + send you email
// alerts, if you've opted into receiving them.
// [START reporterror]
function reportError(err, context = {}) {
  // This is the name of the StackDriver log stream that will receive the log
  // entry. This name can be any valid log stream name, but must contain "err"
  // in order for the error to be picked up by StackDriver Error Reporting.
  const logName = 'errors';
  const log = logging.log(logName);

  // https://cloud.google.com/logging/docs/api/ref_v2beta1/rest/v2beta1/MonitoredResource
  const metadata = {
    resource: {
      type: 'cloud_function',
      labels: {function_name: process.env.FUNCTION_NAME},
    },
  };

  // https://cloud.google.com/error-reporting/reference/rest/v1beta1/ErrorEvent
  const errorEvent = {
    message: err.stack,
    serviceContext: {
      service: process.env.FUNCTION_NAME,
      resourceType: 'cloud_function',
    },
    context: context,
  };

  // Write the error log entry
  return new Promise((resolve, reject) => {
    log.write(log.entry(metadata, errorEvent), (error) => {
      if (error) {
       return reject(error);
      }
      return resolve();
    });
  });
}
// [END reporterror]

// Sanitize the error message for the user
function userFacingMessage(error) {
  // return error.type ? error.message : 'An error occurred, developers have been alerted';
  return error.message;
}