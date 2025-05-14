import os
import boto3
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Literal
from uuid import uuid4
from datetime import datetime
from decimal import Decimal
from mangum import Mangum

# Inicializar FastAPI y CORS
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Conectar a DynamoDB
dynamo = boto3.resource("dynamodb")
table_name = os.getenv("DYNAMO_TABLE", "Reminders")
table = dynamo.Table(table_name)

# Modelos Pydantic con campo phone_number
typing_units = Literal["days", "hours"]

class ReminderBase(BaseModel):
    title: str
    datetime: datetime
    lead_amount: int = 1
    lead_unit: typing_units = "days"
    phone_number: str

class ReminderCreate(ReminderBase):
    pass

class ReminderUpdate(BaseModel):
    title: Optional[str]
    datetime: Optional[datetime]
    lead_amount: Optional[int]
    lead_unit: Optional[typing_units]
    phone_number: Optional[str]

class Reminder(ReminderBase):
    id: str

# Normalizar tipos de Dynamo
def _normalize_item(item: dict) -> dict:
    if isinstance(item.get("lead_amount"), Decimal):
        item["lead_amount"] = int(item["lead_amount"])
    return item

# CRUD Endpoints
@app.get("/reminders", response_model=List[Reminder])
def read_reminders():
    resp = table.scan()
    items = resp.get("Items", [])
    return [_normalize_item(i) for i in items]

@app.post("/reminders", response_model=Reminder)
def create_reminder(reminder: ReminderCreate):
    item = reminder.dict()
    item["id"] = str(uuid4())
    item["datetime"] = reminder.datetime.isoformat()
    item["lead_amount"] = Decimal(reminder.lead_amount)
    table.put_item(Item=item)
    return item

@app.put("/reminders/{reminder_id}", response_model=Reminder)
def update_reminder(reminder_id: str, reminder: ReminderUpdate):
    resp = table.get_item(Key={"id": reminder_id})
    if "Item" not in resp:
        raise HTTPException(status_code=404, detail="Reminder not found")
    item = resp["Item"]
    update_data = reminder.dict(exclude_unset=True)
    if "datetime" in update_data:
        update_data["datetime"] = update_data["datetime"].isoformat()
    if "lead_amount" in update_data:
        update_data["lead_amount"] = Decimal(update_data["lead_amount"])
    item.update(update_data)
    table.put_item(Item=item)
    return _normalize_item(item)

@app.delete("/reminders/{reminder_id}", status_code=204)
def delete_reminder(reminder_id: str):
    resp = table.get_item(Key={"id": reminder_id})
    if "Item" not in resp:
        raise HTTPException(status_code=404, detail="Reminder not found")
    table.delete_item(Key={"id": reminder_id})
    return None

# Handler AWS Lambda
handler = Mangum(app)
