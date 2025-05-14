import React, { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Container, Typography, Box, Button, Stack } from '@mui/material'
import ReminderCard from '../components/ReminderCard.jsx'
import { getReminders } from '../services/api.js'

export default function Dashboard() {
  const [reminders, setReminders] = useState([])
  const navigate = useNavigate()

  useEffect(() => {
    getReminders().then(setReminders)
  }, [])

  // Callback que elimina un reminder del estado
  const handleDelete = (id) => {
    setReminders(prev => prev.filter(r => r.id !== id))
  }

  return (
    <Container sx={{ mt: 8 }}>
      <Stack direction="row" justifyContent="space-between" alignItems="center" mb={4}>
        <Typography variant="h4">Tus Recordatorios</Typography>
        <Button variant="contained" onClick={() => navigate('/new')}>
          + Nuevo
        </Button>
      </Stack>
      <Box display="grid" gridTemplateColumns="repeat(auto-fill,minmax(280px,1fr))" gap={2}>
        {reminders.map(r => (
          <ReminderCard
            key={r.id}
            reminder={r}
            onDelete={handleDelete}   // 👈 pasamos el callback
          />
        ))}
      </Box>
    </Container>
  )
}
