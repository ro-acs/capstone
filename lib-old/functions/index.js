const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
admin.initializeApp();

const PAYPAL_CLIENT_ID = "YOUR-SANDBOX-CLIENT-ID";
const PAYPAL_SECRET = "YOUR-SANDBOX-SECRET";

// Create PayPal Order
exports.createPayPalOrder = functions.https.onRequest(async (req, res) => {
  const auth = Buffer.from(`${PAYPAL_CLIENT_ID}:${PAYPAL_SECRET}`).toString("base64");

  // Step 1: Get Access Token
  const tokenRes = await axios.post(
    "https://api-m.sandbox.paypal.com/v1/oauth2/token",
    "grant_type=client_credentials",
    {
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    }
  );

  const accessToken = tokenRes.data.access_token;

  // Step 2: Create Order
  const orderRes = await axios.post(
    "https://api-m.sandbox.paypal.com/v2/checkout/orders",
    {
      intent: "CAPTURE",
      purchase_units: [
        {
          amount: {
            currency_code: "USD",
            value: "5.00",
          },
        },
      ],
      application_context: {
        return_url: "https://your-app.firebaseapp.com/paypal-success",
        cancel_url: "https://your-app.firebaseapp.com/paypal-cancel",
      },
    },
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
    }
  );

  const approvalUrl = orderRes.data.links.find((link) => link.rel === "approve").href;

  res.json({ url: approvalUrl });
});
