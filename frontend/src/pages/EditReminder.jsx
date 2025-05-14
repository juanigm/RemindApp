// src/pages/EditReminder.jsx
import React, { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  Container, Paper, Typography, Box,
  TextField, Button, FormControl, InputLabel, Select, MenuItem
} from '@mui/material'
import { getReminders, updateReminder } from '../services/api.js'

export default function EditReminder() {
  const { id } = useParams()
  const navigate = useNavigate()

  const [title, setTitle] = useState('')
  const [datetime, setDatetime] = useState('')      // deberá ser 'YYYY-MM-DDTHH:mm'
  const [leadAmount, setLeadAmount] = useState(1)
  const [leadUnit, setLeadUnit] = useState('days')
  const [phoneNumber, setPhoneNumber] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    getReminders()
      .then(all => {
        const r = all.find(x => x.id === id)
        if (!r) throw new Error('Recordatorio no encontrado')
        setTitle(r.title)
        // Convertimos el string de la API a ISO-local para el input
        const dtIso = new Date(r.datetime).toISOString().slice(0,16)
        setDatetime(dtIso)
        setLeadAmount(r.lead_amount ?? r.leadAmount ?? 1)
        setLeadUnit(r.lead_unit ?? r.leadUnit ?? 'days')
        setPhoneNumber(r.phone_number ?? '')
      })
      .catch(err => {
        console.error(err)
        navigate('/dashboard')
      })
      .finally(() => setLoading(false))
  }, [id])

  const handleSubmit = async e => {
    e.preventDefault()
    // Validaciones básicas
    if (!title.trim() || !datetime) {
      return alert('Título y Fecha/Hora son obligatorios y válidos.')
    }
    try {
      await updateReminder(id, {
        title,
        datetime,
        leadAmount: Number(leadAmount),
        leadUnit,
        phoneNumber
      })
      navigate('/dashboard')
    } catch (err) {
      console.error(err)
      alert('Error guardando cambios: ' + err.message)
    }
  }

  if (loading) {
    return <Typography align="center" sx={{ mt:4 }}>Cargando...</Typography>
  }

  return (
    <Container maxWidth="sm" sx={{ mt: 8 }}>
      <Paper elevation={3} sx={{ p: 4 }}>
        <Typography variant="h5" align="center" gutterBottom>
          Editar Recordatorio
        </Typography>
        <Box component="form" onSubmit={handleSubmit} noValidate>
          <TextField
            label="Título"
            fullWidth margin="normal"
            value={title}
            onChange={e => setTitle(e.target.value)}
          />

          <TextField
            label="Fecha y hora"
            type="datetime-local"
            fullWidth margin="normal"
            InputLabelProps={{ shrink: true }}
            value={datetime}
            onChange={e => setDatetime(e.target.value)}
          />

          <TextField
            label="Enviar X antes"
            type="number"
            fullWidth margin="normal"
            value={leadAmount}
            onChange={e => setLeadAmount(e.target.value)}
            helperText={`Cantidad de ${leadUnit}`}
          />

          <FormControl fullWidth margin="normal">
            <InputLabel id="lead-unit-label">Unidad</InputLabel>
            <Select
              labelId="lead-unit-label"
              value={leadUnit}
              label="Unidad"
              onChange={e => setLeadUnit(e.target.value)}
            >
              <MenuItem value="days">Días</MenuItem>
              <MenuItem value="hours">Horas</MenuItem>
            </Select>
          </FormControl>

          <Button
            type="submit"
            variant="contained"
            fullWidth
            sx={{ mt: 2 }}
          >
            Guardar Cambios
          </Button>
        </Box>
      </Paper>
    </Container>
  )
}
