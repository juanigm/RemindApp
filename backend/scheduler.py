import os
import boto3
from twilio.rest import Client
from datetime import datetime, timezone, timedelta
from decimal import Decimal

# Configuración desde variables de entorno
TABLE_NAME    = os.getenv("DYNAMO_TABLE")
TW_SID        = os.getenv("TWILIO_ACCOUNT_SID")
TW_TOKEN      = os.getenv("TWILIO_AUTH_TOKEN")
WA_FROM       = os.getenv("TWILIO_WHATSAPP_FROM")

# Conexión
dynamo = boto3.resource("dynamodb")
table  = dynamo.Table(TABLE_NAME)
twilio = Client(TW_SID, TW_TOKEN)

def send_whatsapp(to: str, body: str):
    twilio.messages.create(
        from_=WA_FROM,
        to=f"whatsapp:{to}",
        body=body
    )

def lambda_handler(event, context):
    now = datetime.now(timezone.utc)
    # 1) Escaneo todos los reminders aún no enviados
    resp = table.scan(
        FilterExpression="attribute_not_exists(sent)"
    )
    for item in resp.get("Items", []):
        send_at   = datetime.fromisoformat(item["datetime"])
        lead_amt  = int(item["lead_amount"])
        lead_unit = item["lead_unit"]  # "days" u "hours"
        delta     = timedelta(**{lead_unit: lead_amt})
        trigger   = send_at - delta

        if now >= trigger:
            # 2) Construyo el mensaje
            body = (
                f"⏰ *{item['title']}*\n"
                f"🗓️ {send_at:%Y-%m-%d %H:%M}\n"
                f"📱 ¡Este es tu recordatorio!"
            )
            # 3) Envío por WhatsApp
            send_whatsapp(item["phone_number"], body)

            # 4) Marco como enviado
            table.update_item(
                Key={"id": item["id"]},
                UpdateExpression="SET sent = :true",
                ExpressionAttributeValues={":true": True}
            )
    return {"status": "ok"}
