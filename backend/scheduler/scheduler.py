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

print(f"[scheduler:init] DYNAMO_TABLE={TABLE_NAME}, "
      f"TWILIO_ACCOUNT_SID={'SET' if TW_SID else 'MISSING'}, "
      f"TWILIO_AUTH_TOKEN={'SET' if TW_TOKEN else 'MISSING'}, "
      f"TWILIO_WHATSAPP_FROM={WA_FROM}")

# Conexión
dynamo = boto3.resource("dynamodb")
table  = dynamo.Table(TABLE_NAME)
twilio = Client(TW_SID, TW_TOKEN)

def send_whatsapp(to: str, body: str):
    print(f"[send_whatsapp] from={WA_FROM} to={to!r} body={body!r}")
    try:
        msg = twilio.messages.create(
            from_=WA_FROM,
            to=f"whatsapp:{to}",
            body=body
        )
        print(f"[send_whatsapp] SID={msg.sid} status={msg.status}")
    except Exception as e:
        print(f"[send_whatsapp:error] {e!r}")
        raise

def lambda_handler(event, context):
    # 1) Hora actual en UTC (aware)
    now = datetime.now(timezone.utc)
    print(f"[scheduler] now = {now.isoformat()}")

    # 2) Escaneo todos los reminders aún no enviados
    resp = table.scan(FilterExpression="attribute_not_exists(sent)")
    for item in resp.get("Items", []):
        # Parseo el ISO timestamp
        send_at = datetime.fromisoformat(item["datetime"])
        # Si viene *naive* (sin tzinfo), lo marcamos como UTC
        if send_at.tzinfo is None:
            send_at = send_at.replace(tzinfo=timezone.utc)
        else:
            # si ya fuese aware, lo convertimos a UTC para normalizar
            send_at = send_at.astimezone(timezone.utc)

        lead_amt  = int(item["lead_amount"])
        lead_unit = item["lead_unit"]      # "days" u "hours"
        delta     = timedelta(**{lead_unit: lead_amt})
        trigger   = send_at - delta

        print(f"→ record id={item['id']} send_at={send_at.isoformat()} trigger={trigger.isoformat()} now={now.isoformat()}")

        # Ya podemos comparar
        if now >= trigger:
            body = (
                f"⏰ *{item['title']}*\n"
                f"🗓️ {send_at:%Y-%m-%d %H:%M}\n"
                f"📱 ¡Este es tu recordatorio!"
            )
            try:
                send_whatsapp(item["phone_number"], body)
                print(f"[scheduler] enviado a {item['phone_number']}")
            except Exception as e:
                print(f"[scheduler][ERROR] fallo al enviar WhatsApp: {e!r}")
                continue

            # Marco en DynamoDB
            table.update_item(
                Key={"id": item["id"]},
                UpdateExpression="SET sent = :true",
                ExpressionAttributeValues={":true": True}
            )
            print(f"[scheduler] marcado 'sent' id={item['id']}")
        else:
            print(f"[scheduler] todavía no toca el recordatorio id={item['id']}")

    return {"status": "ok"}

