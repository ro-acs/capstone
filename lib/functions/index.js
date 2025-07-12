const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const cors = require("cors")({ origin: true });

admin.initializeApp();

const PAYMONGO_SECRET = 'sk_test_YOUR_SECRET_KEY'; // Replace with your actual PayMongo secret key

exports.generateGcashPaymentUrl = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    if (req.method !== "POST") {
      return res.status(405).send("Method Not Allowed");
    }

    const { amount, name, email } = req.body;

    if (!amount || !name || !email) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    try {
      // Step 1: Create Payment Intent
      const intentRes = await axios.post(
        'https://api.paymongo.com/v1/payment_intents',
        {
          data: {
            attributes: {
              amount: amount,
              payment_method_allowed: ['gcash'],
              payment_method_options: {
                gcash: {
                  redirect: {
                    success: 'https://your-app.com/success',
                    failed: 'https://your-app.com/fail',
                  },
                },
              },
              currency: 'PHP',
              capture_type: 'automatic',
            },
          },
        },
        {
          headers: {
            Authorization: `Basic ${Buffer.from(PAYMONGO_SECRET + ":").toString("base64")}`,
            'Content-Type': 'application/json',
          },
        }
      );

      const clientKey = intentRes.data.data.attributes.client_key;
      const intentId = intentRes.data.data.id;

      // Step 2: Create Payment Method
      const methodRes = await axios.post(
        'https://api.paymongo.com/v1/payment_methods',
        {
          data: {
            attributes: {
              type: 'gcash',
              billing: {
                name,
                email,
              },
            },
          },
        },
        {
          headers: {
            Authorization: `Basic ${Buffer.from(PAYMONGO_SECRET + ":").toString("base64")}`,
            'Content-Type': 'application/json',
          },
        }
      );

      const paymentMethodId = methodRes.data.data.id;

      // Step 3: Attach to intent
      const attachRes = await axios.post(
        `https://api.paymongo.com/v1/payment_intents/${intentId}/attach`,
        {
          data: {
            attributes: {
              payment_method: paymentMethodId,
              client_key: clientKey,
            },
          },
        },
        {
          headers: {
            Authorization: `Basic ${Buffer.from(PAYMONGO_SECRET + ":").toString("base64")}`,
            'Content-Type': 'application/json',
          },
        }
      );

      const paymentUrl =
        attachRes.data.data.attributes.next_action.redirect.checkout_url;

      return res.status(200).json({ paymentUrl });
    } catch (error) {
      console.error(error.response?.data || error.message);
      return res
        .status(500)
        .json({ error: "Failed to generate GCash payment URL" });
    }
  });
});
