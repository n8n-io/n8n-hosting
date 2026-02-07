import type { Metadata } from 'next'
import {
  ClerkProvider,
  SignInButton,
  SignUpButton,
  SignedIn,
  SignedOut,
  UserButton,
} from '@clerk/nextjs'
import './globals.css'

export const metadata: Metadata = {
  title: 'Clerk Next.js App',
  description: 'Next.js App Router with Clerk authentication',
}

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <ClerkProvider>
      <html lang="en">
        <body>
          <header className="header">
            <nav className="nav">
              <a href="/" className="logo">
                Clerk + Next.js
              </a>
              <div className="auth-buttons">
                <SignedOut>
                  <SignInButton>
                    <button className="btn btn-secondary">Sign In</button>
                  </SignInButton>
                  <SignUpButton>
                    <button className="btn btn-primary">Sign Up</button>
                  </SignUpButton>
                </SignedOut>
                <SignedIn>
                  <UserButton
                    appearance={{
                      elements: {
                        avatarBox: 'w-10 h-10',
                      },
                    }}
                  />
                </SignedIn>
              </div>
            </nav>
          </header>
          <main className="main">{children}</main>
        </body>
      </html>
    </ClerkProvider>
  )
}
