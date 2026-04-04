import { Head, useForm, usePage } from '@inertiajs/react'
import AuthLayout from './AuthLayout'

interface RegisterTranslations {
  title: string
  email: string
  password: string
  password_confirmation: string
  submit: string
  have_account: string
  login_link: string
}

interface RegisterProps {
  translations: RegisterTranslations
  errors?: Record<string, string[]>
}

interface SharedProps {
  flash?: {
    notice?: string
    alert?: string
  }
  [key: string]: unknown
}

export default function Register({ translations, errors = {} }: RegisterProps) {
  const { flash } = usePage<SharedProps>().props

  const { data, setData, post, processing } = useForm({
    user: {
      email: '',
      password: '',
      password_confirmation: '',
    }
  })

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    post('/users')
  }

  function fieldClass(field: string) {
    return `w-full px-3 py-2 border rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 ${
      errors[field] ? 'border-red-500' : 'border-gray-300'
    }`
  }

  return (
    <AuthLayout>
      <Head title={translations.title} />

      <h1 className="text-2xl font-semibold text-gray-900 mb-6">{translations.title}</h1>

      {flash?.notice && (
        <div className="mb-4 px-4 py-3 rounded-md bg-green-500 text-white text-sm">
          {flash.notice}
        </div>
      )}

      {flash?.alert && (
        <div className="mb-4 px-4 py-3 rounded-md bg-red-500 text-white text-sm">
          {flash.alert}
        </div>
      )}

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
            className={fieldClass('email')}
            required
          />
          {errors.email && (
            <p className="mt-1 text-xs text-red-600">{errors.email[0]}</p>
          )}
        </div>

        <div>
          <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
            {translations.password}
          </label>
          <input
            id="password"
            type="password"
            autoComplete="new-password"
            value={data.user.password}
            onChange={e => setData('user', { ...data.user, password: e.target.value })}
            className={fieldClass('password')}
            required
          />
          {errors.password && (
            <p className="mt-1 text-xs text-red-600">{errors.password[0]}</p>
          )}
        </div>

        <div>
          <label htmlFor="password_confirmation" className="block text-sm font-medium text-gray-700 mb-1">
            {translations.password_confirmation}
          </label>
          <input
            id="password_confirmation"
            type="password"
            autoComplete="new-password"
            value={data.user.password_confirmation}
            onChange={e => setData('user', { ...data.user, password_confirmation: e.target.value })}
            className={fieldClass('password_confirmation')}
            required
          />
          {errors.password_confirmation && (
            <p className="mt-1 text-xs text-red-600">{errors.password_confirmation[0]}</p>
          )}
        </div>

        <button
          type="submit"
          disabled={processing}
          className="w-full py-2 px-4 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-md transition-colors disabled:opacity-50"
        >
          {translations.submit}
        </button>

        <div className="text-center text-sm text-gray-500">
          {translations.have_account}{' '}
          <a href="/users/sign_in" className="text-indigo-600 hover:underline">
            {translations.login_link}
          </a>
        </div>
      </form>
    </AuthLayout>
  )
}
