import { Head, Link, useForm, usePage } from '@inertiajs/react'
import AuthLayout from '../auth/AuthLayout'

interface ProfileTranslations {
  title: string
  back_to_home: string
  email: {
    section_title: string
    current_email_label: string
    new_email_label: string
    new_email_placeholder: string
    submit: string
    pending_confirmation: string
    same_as_current: string
  }
  password: {
    section_title: string
    current_password_label: string
    current_password_placeholder: string
    new_password_label: string
    new_password_placeholder: string
    password_confirmation_label: string
    password_confirmation_placeholder: string
    submit: string
    forgot_password: string
  }
}

interface Props {
  translations: ProfileTranslations
  errors?: Record<string, string[]>
}

interface SharedProps {
  current_user?: { id: number; email: string; unconfirmed_email?: string }
  flash?: { notice?: string; alert?: string }
  [key: string]: unknown
}

export default function Show({ translations, errors = {} }: Props) {
  const { current_user, flash } = usePage<SharedProps>().props

  const emailForm = useForm({
    user: { email: '' }
  })

  const passwordForm = useForm({
    user: {
      current_password: '',
      password: '',
      password_confirmation: '',
    }
  })

  function handleEmailSubmit(e: React.FormEvent) {
    e.preventDefault()
    emailForm.patch('/users/profile/email')
  }

  function handlePasswordSubmit(e: React.FormEvent) {
    e.preventDefault()
    passwordForm.patch('/users/profile/password')
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

      {/* Email section */}
      <div className="mb-6">
        <h2 className="text-lg font-medium text-gray-800 mb-4">{translations.email.section_title}</h2>

        <div className="mb-3 text-sm text-gray-600">
          <span className="font-medium">{translations.email.current_email_label}:</span>{' '}
          {current_user?.email}
        </div>

        {current_user?.unconfirmed_email && (
          <div className="mb-3 text-sm text-yellow-700 bg-yellow-50 border border-yellow-200 rounded-md px-3 py-2">
            {translations.email.pending_confirmation} {current_user.unconfirmed_email}
          </div>
        )}

        <form onSubmit={handleEmailSubmit} className="space-y-4">
          <div>
            <label htmlFor="new_email" className="block text-sm font-medium text-gray-700 mb-1">
              {translations.email.new_email_label}
            </label>
            <input
              id="new_email"
              type="email"
              autoComplete="email"
              placeholder={translations.email.new_email_placeholder}
              value={emailForm.data.user.email}
              onChange={e => emailForm.setData('user', { ...emailForm.data.user, email: e.target.value })}
              className={fieldClass('email')}
            />
            {errors.email && (
              <p className="mt-1 text-xs text-red-600">{errors.email[0]}</p>
            )}
          </div>

          <button
            type="submit"
            disabled={emailForm.processing}
            className="w-full py-2 px-4 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-md transition-colors disabled:opacity-50"
          >
            {translations.email.submit}
          </button>
        </form>
      </div>

      <hr className="my-6 border-gray-200" />

      {/* Password section */}
      <div className="mb-6">
        <h2 className="text-lg font-medium text-gray-800 mb-4">{translations.password.section_title}</h2>

        <form onSubmit={handlePasswordSubmit} className="space-y-4">
          <div>
            <label htmlFor="current_password" className="block text-sm font-medium text-gray-700 mb-1">
              {translations.password.current_password_label}
            </label>
            <input
              id="current_password"
              type="password"
              autoComplete="current-password"
              placeholder={translations.password.current_password_placeholder}
              value={passwordForm.data.user.current_password}
              onChange={e => passwordForm.setData('user', { ...passwordForm.data.user, current_password: e.target.value })}
              className={fieldClass('current_password')}
            />
            {errors.current_password && (
              <p className="mt-1 text-xs text-red-600">{errors.current_password[0]}</p>
            )}
          </div>

          <div>
            <label htmlFor="new_password" className="block text-sm font-medium text-gray-700 mb-1">
              {translations.password.new_password_label}
            </label>
            <input
              id="new_password"
              type="password"
              autoComplete="new-password"
              placeholder={translations.password.new_password_placeholder}
              value={passwordForm.data.user.password}
              onChange={e => passwordForm.setData('user', { ...passwordForm.data.user, password: e.target.value })}
              className={fieldClass('password')}
            />
            {errors.password && (
              <p className="mt-1 text-xs text-red-600">{errors.password[0]}</p>
            )}
          </div>

          <div>
            <label htmlFor="password_confirmation" className="block text-sm font-medium text-gray-700 mb-1">
              {translations.password.password_confirmation_label}
            </label>
            <input
              id="password_confirmation"
              type="password"
              autoComplete="new-password"
              placeholder={translations.password.password_confirmation_placeholder}
              value={passwordForm.data.user.password_confirmation}
              onChange={e => passwordForm.setData('user', { ...passwordForm.data.user, password_confirmation: e.target.value })}
              className={fieldClass('password_confirmation')}
            />
            {errors.password_confirmation && (
              <p className="mt-1 text-xs text-red-600">{errors.password_confirmation[0]}</p>
            )}
          </div>

          <div className="text-right text-sm">
            <a href="/users/password/new" className="text-indigo-600 hover:underline">
              {translations.password.forgot_password}
            </a>
          </div>

          <button
            type="submit"
            disabled={passwordForm.processing}
            className="w-full py-2 px-4 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-md transition-colors disabled:opacity-50"
          >
            {translations.password.submit}
          </button>
        </form>
      </div>

      <hr className="my-6 border-gray-200" />

      <div className="text-center">
        <Link href="/" className="text-sm text-gray-500 hover:text-gray-700 hover:underline">
          {translations.back_to_home}
        </Link>
      </div>
    </AuthLayout>
  )
}
