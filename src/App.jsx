import React from 'react'
import { Routes, Route } from 'react-router-dom'

export default function App() {
  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white border-b border-gray-200 px-6 py-4">
        <h1 className="text-xl font-semibold text-gray-800">Brainbox Candy — Trade CRM</h1>
      </header>
      <main className="p-6">
        <Routes>
          <Route path="/" element={<div className="text-gray-500">Dashboard coming soon…</div>} />
        </Routes>
      </main>
    </div>
  )
}
