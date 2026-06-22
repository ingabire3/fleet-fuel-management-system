I built a full-stack fleet fuel management system end-to-end — backend, mobile app, and now a public deployment.

**The problem:** fleets lose money to fuel fraud and waste because nobody can answer "is this fuel use actually consistent with where the vehicle went?" in real time.

**What I built — Fleet Fuel Management System:**
🔹 GPS route tracking with deviation detection against pre-approved routes
🔹 Dynamic fuel allocation calculated from commute distance, working days, and live fuel prices — not a flat monthly guess
🔹 Fuel request → approval workflow with a full audit trail
🔹 OTP-verified login, role-based access (Admin / Fleet Manager / Driver)
🔹 Push notifications for requests, approvals, and security alerts
🔹 PDF reports and an analytics dashboard with anomaly detection

**Stack:** Flutter (Android/iOS/Web) → Node.js/Express/TypeScript API → Prisma ORM → PostgreSQL (Supabase) → Firebase (push). Deployed on Render + Vercel, fully free-tier.

**The outcome:** a fleet manager can see, in one dashboard, whether a driver's fuel consumption matches their actual GPS-logged trips — and get flagged automatically when it doesn't.

🔗 Live demo: <demo-link>
💻 Code: <github-link>
📄 API docs: <api-docs-link>

#FlutterDev #NodeJS #FullStackDevelopment #SoftwareEngineering #FleetManagement
