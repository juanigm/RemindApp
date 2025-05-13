// src/components/ReminderCard.jsx
import React from 'react'
import {
  Card, CardContent, Typography,
  CardActions, IconButton
} from '@mui/material'
import EditIcon from '@mui/icons-material/Edit'
import DeleteIcon from '@mui/icons-material/Delete'
import { useNavigate } from 'react-router-dom'
import { deleteReminder } from '../services/api.js'

export default function ReminderCard({ reminder, onDelete }) {
  const { id, title, datetime, leadAmount, leadUnit } = reminder
  const date = new Date(datetime).toLocaleString()
  const navigate = useNavigate()

  const handleDelete = async () => {
    if (confirm('¿Eliminar este recordatorio?')) {
      await deleteReminder(id)
      onDelete(id)
    }
  }

  return (
    <Card>
      <CardContent>
        <Typography variant="h6">{title}</Typography>
        <Typography variant="body2" color="text.secondary">
          Evento: {date}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Se enviará {leadAmount} {leadUnit === 'days' ? 'día(s)' : 'hora(s)'} antes
        </Typography>
      </CardContent>
      <CardActions>
        <IconButton onClick={() => navigate(`/edit/${id}`)} size="small">
          <EditIcon />
        </IconButton>
        <IconButton onClick={handleDelete} size="small">
          <DeleteIcon />
        </IconButton>
      </CardActions>
    </Card>
  )
}
