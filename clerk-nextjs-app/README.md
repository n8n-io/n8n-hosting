# Clerk + Next.js App Router

A Next.js application with Clerk authentication pre-configured using the App Router architecture.

## Features

- **Next.js 15** with App Router
- **Clerk Authentication** with keyless mode
- **TypeScript** for type safety
- **Modern UI** with custom CSS

## Getting Started

### 1. Install Dependencies

```bash
npm install
```

### 2. Run the Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

### 3. Sign Up / Sign In

Click the **Sign Up** or **Sign In** button in the header. Clerk handles authentication automatically with **keyless mode**—no API keys or Clerk account required to start!

### 4. Claim Your Application (Optional)

When you're ready for production, click **"Claim your application"** in the bottom-right corner of your app to link it to your Clerk account and access the full Dashboard.

## Project Structure

```
clerk-nextjs-app/
├── src/
│   ├── app/
│   │   ├── layout.tsx      # Root layout with ClerkProvider
│   │   ├── page.tsx        # Homepage
│   │   └── globals.css     # Global styles
│   └── proxy.ts            # Clerk middleware
├── public/
├── package.json
├── tsconfig.json
├── next.config.ts
└── README.md
```

## Key Files

### `src/proxy.ts`

The middleware file that enables Clerk authentication across your app:

```typescript
import { clerkMiddleware } from '@clerk/nextjs/server'

export default clerkMiddleware()

export const config = {
  matcher: [
    '/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)',
    '/(api|trpc)(.*)',
  ],
}
```

### `src/app/layout.tsx`

The root layout wraps your app with `<ClerkProvider>` and includes authentication components:

```typescript
import { ClerkProvider, SignInButton, SignUpButton, SignedIn, SignedOut, UserButton } from '@clerk/nextjs'
```

## Protecting Routes

To protect specific routes, modify the middleware:

```typescript
import { clerkMiddleware, createRouteMatcher } from '@clerk/nextjs/server'

const isProtectedRoute = createRouteMatcher(['/dashboard(.*)', '/profile(.*)'])

export default clerkMiddleware(async (auth, req) => {
  if (isProtectedRoute(req)) {
    await auth.protect()
  }
})
```

## Environment Variables (Optional)

For production, you'll need Clerk API keys. After claiming your application:

```env
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_***
CLERK_SECRET_KEY=sk_***
```

## Learn More

- [Clerk Documentation](https://clerk.com/docs)
- [Next.js Documentation](https://nextjs.org/docs)
- [Clerk + Next.js Quickstart](https://clerk.com/docs/quickstarts/nextjs)

## License

MIT
