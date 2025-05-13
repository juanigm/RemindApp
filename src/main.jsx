// src/main.jsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { CssBaseline, ThemeProvider, createTheme } from '@mui/material'

import Login from './pages/Login.jsx'
import Dashboard from './pages/Dashboard.jsx'
import NewReminder from './pages/NewReminder.jsx'
import EditReminder from './pages/EditReminder.jsx'   // 👈 importar

const theme = createTheme({
  palette: {
    primary: { main: '#1976d2' },
    background: { default: '#f5f5f5' }
  }
})

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Login />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/new" element={<NewReminder />} />
          <Route path="/edit/:id" element={<EditReminder />} /> {/* 👈 ruta para editar */}
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
  </React.StrictMode>
)

