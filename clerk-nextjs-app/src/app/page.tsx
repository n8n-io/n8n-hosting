import { SignedIn, SignedOut } from '@clerk/nextjs'

export default function Home() {
  return (
    <div className="container">
      <section className="hero">
        <h1 className="title">
          Welcome to <span className="highlight">Clerk + Next.js</span>
        </h1>
        <p className="subtitle">
          A modern authentication solution with keyless development mode
        </p>

        <SignedOut>
          <div className="card">
            <h2>Get Started</h2>
            <p>
              Click <strong>Sign Up</strong> or <strong>Sign In</strong> in the
              header to authenticate. Clerk handles everything automatically
              with keyless mode—no API keys required to start developing!
            </p>
            <ul className="features">
              <li>Zero configuration required</li>
              <li>Instant authentication setup</li>
              <li>Claim your application when ready</li>
            </ul>
          </div>
        </SignedOut>

        <SignedIn>
          <div className="card success">
            <h2>You&apos;re Signed In!</h2>
            <p>
              Congratulations! You&apos;ve successfully authenticated with
              Clerk. Your user session is now active.
            </p>
            <p>
              Click your avatar in the header to manage your account or sign
              out.
            </p>
          </div>
        </SignedIn>
      </section>

      <section className="info">
        <h2>About This Template</h2>
        <div className="info-grid">
          <div className="info-card">
            <h3>App Router</h3>
            <p>
              Built with Next.js App Router architecture using the latest React
              Server Components.
            </p>
          </div>
          <div className="info-card">
            <h3>Clerk Authentication</h3>
            <p>
              Pre-configured with Clerk for secure, modern authentication out of
              the box.
            </p>
          </div>
          <div className="info-card">
            <h3>Keyless Mode</h3>
            <p>
              Start developing immediately. Claim your application when
              you&apos;re ready for production.
            </p>
          </div>
        </div>
      </section>
    </div>
  )
}
