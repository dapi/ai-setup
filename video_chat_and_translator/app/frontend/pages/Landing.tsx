import { Head, Link, router, usePage } from '@inertiajs/react'
import Toast from '../components/Toast'

interface LandingProps {
  app_name: string
}

interface SharedProps {
  current_user?: { id: number; email: string }
  [key: string]: unknown
}

export default function Landing({ app_name }: LandingProps) {
  const { current_user } = usePage<SharedProps>().props

  function handleSignOut() {
    router.delete('/users/sign_out')
  }

  return (
    <>
      <Head title={app_name} />
      <Toast />
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
        <div className="text-center max-w-2xl px-6">
          <h1 className="text-5xl font-bold text-gray-900 mb-6">
            {app_name}
          </h1>
          <p className="text-xl text-gray-600 mb-8">
            AI-powered educational platform with real-time video translation
            and dubbing — all running locally in your browser.
          </p>
          <div className="flex gap-4 justify-center flex-wrap mb-6">
            <span className="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-red-100 text-red-800">
              Rails 8
            </span>
            <span className="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
              React + Inertia.js
            </span>
            <span className="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-sky-100 text-sky-800">
              TypeScript
            </span>
            <span className="inline-flex items-center px-4 py-2 rounded-full text-sm font-medium bg-cyan-100 text-cyan-800">
              Tailwind CSS
            </span>
          </div>
          {current_user && (
            <div className="flex flex-col items-center gap-2">
              <span className="text-sm text-gray-500">{current_user.email}</span>
              <div className="flex gap-2">
                <Link
                  href="/users/profile"
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm rounded-md transition-colors"
                >
                  Профиль
                </Link>
                <button
                  onClick={handleSignOut}
                  className="px-4 py-2 bg-gray-700 hover:bg-gray-800 text-white text-sm rounded-md transition-colors"
                >
                  Выйти
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </>
  )
}
