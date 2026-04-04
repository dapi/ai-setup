import { Head, useForm, usePage } from '@inertiajs/react'
import { useState } from 'react'
import AuthLayout from './AuthLayout'

interface LoginTranslations {
  title: string
  email: string
  password: string
  submit: string
  no_account: string
  register_link: string
  resend_email: string
}

interface LoginProps {
  translations: LoginTranslations
}

interface SharedProps {
  flash?: {
    notice?: string
    alert?: string
  }
  [key: string]: unknown
}

export default function Login({ translations }: LoginProps) {
  const { flash } = usePage<SharedProps>().props
  const [showResend, setShowResend] = useState(false)
  const [resendEmail, setResendEmail] = useState('')

  const { data, setData, post, processing } = useForm({
    user: {
      email: '',
      password: '',
    }
  })

  const resendForm = useForm({ email: '' })

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    post('/users/sign_in')
  }

  function handleResend(e: React.FormEvent) {
    e.preventDefault()
    resendForm.setData('email', resendEmail)
    resendForm.post('/users/confirmations/resend')
  }

  return (
    <AuthLayout>
      <Head title={translations.title} />

      <h1 className="text-2xl font-semibold text-gray-900 mb-6">{translations.title}</h1>

      {flash?.alert && (
        <div className="mb-4 px-4 py-3 rounded-md bg-red-500 text-white text-sm">
          {flash.alert}
        </div>
      )}

      {flash?.notice && (
        <div className="mb-4 px-4 py-3 rounded-md bg-green-500 text-white text-sm">
          {flash.notice}
        </div>
      )}

      {processing ? (
        <div className="flex justify-center items-center py-12">
          <svg className="animate-spin h-8 w-8 text-indigo-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"></path>
          </svg>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
              {translations.email}
            </label>
            <input
              id="email"
              type="email"
              autoComplete="email"
              value={data.user.email}
              onChange={e => setData('user', { ...data.user, email: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              required
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
              {translations.password}
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              value={data.user.password}
              onChange={e => setData('user', { ...data.user, password: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              required
            />
          </div>

          <button
            type="submit"
            className="w-full py-2 px-4 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-md transition-colors"
          >
            {translations.submit}
          </button>

          <div className="text-center text-sm text-gray-500">
            {translations.no_account}{' '}
            <a href="/users/sign_up" className="text-indigo-600 hover:underline">
              {translations.register_link}
            </a>
          </div>

          <div className="text-center">
            <button
              type="button"
              onClick={() => setShowResend(!showResend)}
              className="text-sm text-gray-400 hover:text-gray-600 underline"
            >
              {translations.resend_email}
            </button>
          </div>
        </form>
      )}

      {showResend && (
        <form onSubmit={handleResend} className="mt-4 space-y-3 border-t pt-4">
          <input
            type="email"
            placeholder={translations.email}
            value={resendEmail}
            onChange={e => setResendEmail(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            required
          />
          <button
            type="submit"
            disabled={resendForm.processing}
            className="w-full py-2 px-4 bg-gray-600 hover:bg-gray-700 text-white text-sm font-medium rounded-md transition-colors disabled:opacity-50"
          >
            {translations.resend_email}
          </button>
        </form>
      )}
    </AuthLayout>
  )
}
