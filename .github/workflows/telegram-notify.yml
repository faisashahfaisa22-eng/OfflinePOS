// telegram-notify-v8.3.4.js

const TELEGRAM_BOT_TOKEN = "BO8886602226:AAGL_JGyPt5IMBOIK_VOKsZFPUkQUMc_43QT";
const TELEGRAM_CHAT_ID = "288629321";

async function sendTelegramMessage(message) {
  const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        chat_id: TELEGRAM_CHAT_ID,
        text: message
      })
    });

    const data = await response.json();

    if (data.ok) {
      console.log("Telegram message sent");
    } else {
      console.log("Telegram error:", data);
    }

  } catch (error) {
    console.log("Connection error:", error);
  }
}


// استعمال مثال
function notifyNewSale() {
  sendTelegramMessage(
    "🧾 نوی خرڅلاو ثبت شو\n📦 OfflinePOS App"
  );
}

function notifyCredit(customer, amount) {
  sendTelegramMessage(
    `💰 نوی قرض\n👤 مشتری: ${customer}\n💵 اندازه: ${amount}`
  );
}

function notifyRecovery(customer, amount) {
  sendTelegramMessage(
    `✅ د قرض ریکوري\n👤 مشتری: ${customer}\n💵 اندازه: ${amount}`
  );
}
<script src="telegram-notify-v8.3.4.js"></script>
