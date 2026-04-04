import { usePage } from '@inertiajs/react'
import { useEffect, useState } from 'react'

interface SharedProps {
  flash?: {
    notice?: string
    alert?: string
  }
  [key: string]: unknown
}

export default function Toast() {
  const { flash } = usePage<SharedProps>().props
  const [visible, setVisible] = useState(false)
  const [message, setMessage] = useState('')
  const [type, setType] = useState<'notice' | 'alert'>('notice')

  useEffect(() => {
    if (flash?.notice) {
      setMessage(flash.notice)
      setType('notice')
      setVisible(true)
    } else if (flash?.alert) {
      setMessage(flash.alert)
      setType('alert')
      setVisible(true)
    }

    const timer = setTimeout(() => setVisible(false), 5000)
    return () => clearTimeout(timer)
  }, [flash])

  if (!visible || !message) return null

  return (
    <div
      className={`fixed top-4 right-4 z-50 px-6 py-3 rounded-md shadow-lg text-white text-sm font-medium transition-opacity ${
        type === 'notice' ? 'bg-green-500' : 'bg-red-500'
      }`}
    >
      {message}
    </div>
  )
}
