// src/services/api.js
const API_URL = import.meta.env.VITE_API_URL;

export async function getReminders() {
  const res = await fetch(`${API_URL}/reminders`);
  if (!res.ok) throw new Error('Error fetching reminders');
  return res.json();
}

export async function createReminder({ title, datetime, leadAmount, leadUnit, phoneNumber }) {
  const payload = {
    title,
    datetime,
    lead_amount: leadAmount,
    lead_unit: leadUnit,
    phone_number: phoneNumber
  };
  const res = await fetch(`${API_URL}/reminders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  if (!res.ok) throw new Error('Error creating reminder');
  return res.json();
}

export async function updateReminder(id, { title, datetime, leadAmount, leadUnit, phoneNumber }) {
  const payload = {
    title,
    datetime,
    lead_amount: leadAmount,
    lead_unit: leadUnit,
    phone_number: phoneNumber
  };
  const res = await fetch(`${API_URL}/reminders/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });
  if (!res.ok) throw new Error('Error updating reminder');
  return res.json();
}

export async function deleteReminder(id) {
  const res = await fetch(`${API_URL}/reminders/${id}`, { method: 'DELETE' });
  if (!res.ok) throw new Error('Error deleting reminder');
  return;
}
