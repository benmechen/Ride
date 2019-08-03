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
var nodemailer=require('nodemailer');
const stripe = require('stripe')(functions.config().stripe.token);
stripe.setApiVersion('2019-05-16');
const currency = functions.config().stripe.currency || 'GBP';
var id = null;

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
            // const amount = val.amount;
            const idempotencyKey = context.params.id;
            // const charge = {amount, currency, customer};
            // if (val.source !== null) {
            //   charge.source = val.source;
            // }
            // return stripe.charges.create({
            //   amount: val.total_amount,
            //   currency: val.currency,
            //   source: val.source,
            //   customer: val.customer,
            //   metadata: val.metadata,
            //   transfer_data: {
            //     amount: val.user_amount,
            //     destination: val.destination,
            //   },
            // }, {idempotency_key: idempotencyKey});
            console.log(stripe.paymentIntents);
            return stripe.paymentIntents.create({
              payment_method: val.source,
              customer: val.customer,
              amount: val.total_amount,
              currency: val.currency,
              confirmation_method: 'manual',
              confirm: true,
              setup_future_usage: 'off_session',
              metadata: val.metadata,
              transfer_data: {
                amount: val.user_amount,
                destination: val.destination,
              },
            }, {idempotency_key: idempotencyKey});
          }).then((response) => {
            // If the result is successful, write it back to the database
            return snap.ref.set(response);
          }).catch((error) => {
            // We want to capture errors and render them in a user-friendly way, while
            // still logging an exception with StackDriver
            return snap.ref.child('error').set(userFacingMessage(error));
          // }).then(() => {
          //   // return reportError(error, {user: context.params.userId});
          // });
          })
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
  return stripe.customers.create({
    email: user.email
  }).then((customer) => {
    return admin.database().ref(`/stripe_customers/${user.uid}/customer_id`).set(customer.id);
  });
});

// Create a Stripe Connect account
exports.createStripeAccount = functions.database.ref('/stripe_customers/{userId}/account').onCreate((snap, context) => {
  return stripe.accounts.create({
    type: 'custom',
    country: 'GB',
    business_type: 'individual',
    email: snap.val().email,
  }).then((customer) => {
    return admin.database().ref(`/stripe_customers/${snap.val().id}/account_id`).set(customer.id);
  });
});


// Update a user's account so that they can receive Connect payments
exports.updateStripeCustomer = functions.database.ref('/stripe_customers/{userId}/account').onUpdate((change) => {
    const val = change.after.val();

    if (typeof val.details_submitted !== "undefined") {
      console.log(val.details_submitted)
      console.log("Already submitted")
      return null;
    }

    return admin.database().ref(`/stripe_customers/${val.id}/account_id`)
      .once('value').then((snapshot) => {
        return snapshot.val();
      }).then((customer) => {
        console.log(customer);
        if (val.identity_document === "n/a") {
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
              last_name: val.last_name
            },
            external_account: {
              object: 'bank_account',
              country: 'GB',
              currency: 'gbp',
              routing_number: val.sort_code,
              account_number: val.account_number,
              account_holder_name: val.first_name + " " + val.last_name,
              account_holder_type: 'individual'
            },
          })
        }
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
            routing_number: val.sort_code,
            account_number: val.account_number,
            account_holder_name: val.first_name + " " + val.last_name,
            account_holder_type: 'individual'
          },
        })
        // return stripe.customers.createSource(customer, {source});
      }).then((response) => {
        console.log(response);
        return admin.database().ref(`/stripe_customers/${val.id}/account`).set(response);
      }, (error) => {
        return reportError(error, {user: val.id});
      })
});

// Manually create a Stripe customer for existing accounts, not used in release
exports.manuallyCreateStripeCustomer = functions.database.ref('/manual_stripe_create/{userId}').onCreate((snap, context) => {
    const val = snap.val()
    // return stripe.accounts.create({
    //     type: 'custom',
    //     country: 'GB',
    //     business_type: 'individual',
    //     email: val.email,
    return stripe.customers.create({
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

// Add a bank account to account's external sources
// exports.addBankAccount = functions.database
//     .ref('/stripe_customers/{userId}/account/external_accounts/data/{pushId}').onWrite((change, context) => {
//       const source = change.after.val();
//       if (source === null){
//         return null;
//       }
//       return admin.database().ref(`/stripe_customers/${context.params.userId}/customer_id`)
//           .once('value').then((snapshot) => {
//             return snapshot.val();
//           }).then((customer) => {
//             return stripe.customers.createSource(customer, {
//               source : {
//                 object: "bank_account",
//                 country: "GB",
//                 currency: "GBP",
//                 routing_number: source.sort_code,
//                 account_number: source.account_number,
//                 account_holder_name: source.name,
//                 account_holder_type: 'individual'
//               }
//             });
//           }).then((response) => {
//             return change.after.ref.set(response);
//           }, (error) => {
//             return change.after.ref.child('error').set(userFacingMessage(error));
//           })
// });

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

      id = null
      change.after.ref.parent.once("value", (snapshot) => {
        id = snapshot.val().id;
        console.log(id);
      });

      return admin.database().ref(`/stripe_customers/${context.params.userId}/customer_id`)
          .once('value').then((snapshot) => {
            return snapshot.val();
          }).then((customer) => {
            
            while (id === null) {
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
    .ref('/stripe_customers/{userId}/account/external_account/data/{pushId}/deleted').onWrite((change, context) => {
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


// NOTIFICATIONS

// Send notification on request creation
// exports.sendUserCreateOfferNotification = functions.auth.user().onCreate((user) => {
//     return admin.database().ref(`Users/${user.uid}/token`)
//           .once('value').then((snapshot) => {
//             return snapshot.val();
//           }).then((tokenID) => {
//             console.log(tokenID);
//             var message = {
//               notification: {
//                 title: `15% off all Rides`,
//                 body: `As a thank you for downloading Ride, there will be no fees until 01/04!`
//               },
//               token: tokenID
//             };

//             // Send a message to the device corresponding to the provided
//             // registration token.
//             if ((new Date()).getTime() < new Date("2018-04-01")) {
//               return admin.messaging().send(message);
//             }
//           }).then((response) => {
//               // Response is a message ID string.
//               console.log('Successfully sent message:', response);
//               return response
//             }).catch((error) => {
//               console.log('Error sending message:', error);
//               return error
//             });
// });


// Send notification on request creation
exports.sendRideCreationNotification = functions.database.ref('/Requests/{pushId}').onCreate((snap, context) => {
  const destination_user_id = snap.val().driver;
  const destination_user_name = snap.val().sender_name;
  const date = new Date(snap.val().time * 1000);

    console.log(destination_user_ids);

    return admin.database().ref(`Users/${destination_user_id}/token`)
          .once('value').then((snapshot) => {
            return snapshot.val();
          }).then((tokenID) => {
            console.log(tokenID);
            var message = {
              notification: {
                title: `Ride request from ${destination_user_name}`,
                body: `Pickup from ${snap.val().from.name} at ${date.toLocaleTimeString()} on ${date.toDateString()}`
              },
              apns: {
                payload: {
                  aps: {
                    badge: 1,
                    sound: "default"
                  },
                },
              },
              token: tokenID
            };

            // Send a message to the device corresponding to the provided
            // registration token.
            return admin.messaging().send(message)
          }).then((response) => {
              // Response is a message ID string.
              console.log('Successfully sent message:', response);
              return response
            }).catch((error) => {
              console.log('Error sending message:', error);
              return error
            });
});

exports.sendRideUpdateNotification = functions.database.ref('/Requests/{pushId}').onUpdate((change) => {
  var destination_user_id = "";
  var destination_user_ids = [];
  var title = "";
  var body = "";

  if (change.before.val().status !== change.after.val().status) {
    console.log("Status update");
    if (change.after.val().status === 1) {
      destination_user_id = change.after.val().sender;
    } else if (change.after.val().status === 2) {
      destination_user_id = change.after.val().driver;
    } else if (change.after.val().status === 3) {
      destination_user_id = change.after.val().driver;
    } else if (change.after.val().status === 4) {
      destination_user_id = "split"
      var destination_user_dict = change.after.val().split;

      for (var key in destination_user_dict) {
        if (destination_user_dict.hasOwnProperty(key)) {           
          destination_user_ids.push(key);
        }
      }
    } else {
      return null
    }
    
    if (change.after.val().status === 1) {
      title = `${change.after.val().driver_name}`;
      body = `Ride Update: Price - ${change.after.val().price["total"]}`;
    } else if (change.after.val().status === 2) {
      title = `${change.after.val().sender_name}`;
      body = `Ride Update: Quote accepted`;
    } else if (change.after.val().status === 3) {
      title = `${change.after.val().sender_name}`;
      body = `Ride Update: Payment made`;
    } else if (change.after.val().status === 4) {
      title = `${change.after.val().driver_name}`;
      body = `Ride Update: Payment requested`;
    } else {
      return null
    }
  } else if (change.before.val().last_message !== change.after.val().last_message) {
    console.log("New message");
    if (change.after.val().messages[(change.after.val().last_message)]["sender"] === change.after.val().driver) {
      title = `${change.after.val().driver_name}`;
      destination_user_id = change.after.val().sender;
    } else {
      title = `${change.after.val().sender_name}`;
      destination_user_id = change.after.val().driver;
    }
    body = change.after.val().messages[(change.after.val().last_message)]["message"];
  } else {
    return null
  }

  if (destination_user_id === "split") {
    var promises = []
    for (var i = 0; i < destination_user_ids.length; i++) {
      promises[i] = admin.database().ref(`Users/${destination_user_ids[i]}/token`)
        .once('value').then((snapshot) => {
          return snapshot.val();
        }).then((tokenID) => {
          console.log(tokenID);
          var message = {
            notification: {
              title: title,
              body: body
            }, 
            data: {
                request: change.after.key
            }, 
            apns: {
              payload: {
                aps: {
                  badge: 1,
                  sound: "default"
                },
              },
            },
            token: tokenID
          };

          // Send a message to the device corresponding to the provided
          // registration token.
          return admin.messaging().send(message)
        }).then((response) => {
            // Response is a message ID string.
            console.log('Successfully sent message:', response);
            return response
          }).catch((error) => {
            console.log('Error sending message:', error);
            return error
          });
    }

    return promises
  }
  return admin.database().ref(`Users/${destination_user_id}/token`)
        .once('value').then((snapshot) => {
          return snapshot.val();
        }).then((tokenID) => {
          console.log(tokenID);
          var message = {
            notification: {
              title: title,
              body: body
            }, 
            data: {
                request: change.after.key
            }, 
            apns: {
              payload: {
                aps: {
                  badge: 1,
                  sound: "default"
                },
              },
            },
            token: tokenID
          };

          // Send a message to the device corresponding to the provided
          // registration token.
          return admin.messaging().send(message)
        }).then((response) => {
            // Response is a message ID string.
            console.log('Successfully sent message:', response);
            return response
          }).catch((error) => {
            console.log('Error sending message:', error);
            return error
          });
});


// CONTACT EMAIL - WEB FORM

var transporter = nodemailer.createTransport('smtps://mailmyother3@gmail.com:Trevlorado08!@smtp.gmail.com');

exports.sendMail = functions.https.onRequest((req, res) =>{
    console.log(req.body);

    var mailOptions = {
        to: 'bmechen@icloud.com',
        from: `"${req.body.name}" mailmyother3@gmail.com`,
        subject: 'Ride Support Request',
        html: `<h2>From: ${req.body.name}</h2><h3>Email: ${req.body.email}</h3><br> ${req.body.message}`
    }
    transporter.sendMail(mailOptions,function(err,response){
        if(err){
          console.log(err);
            res.end('Mail not sent');
        }
        else{
            res.end('Mail sent');
        }
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