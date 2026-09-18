Render uchun qo'llanma — n8n deploy qilish (tayyorlangan branch: render-deploy)

1) GitHub va Render ulash
- Render dashboard-ga kiring (https://render.com/), GitHub bilan autentifikatsiya qiling.
- "Create a new service" yoki "Create from repo" orqali zbek939/Zuild_Yordamchi repo-ni tanlang.
- Branch sifatida render-deploy ni tanlang.

2) render.yaml'dan deploy qilish
- Agar Render / GitHub integratsiyasi to'g'ri bo'lsa, Render repo-ni o'qib render.yaml ni avtomatik ishlatishi mumkin.
- Agar emas bo'lsa, o'zingiz Service yarating: "Connect a service -> Web Service -> Docker" va Dockerfile yo'lini Dockerfile qilib belgilang.

3) Secrets va Database
- Render-da "Dashboard -> Environment -> Secrets" orqali quyidagi Secrets ni qo'shing:
  - DATABASE_URL (agar Render-managed Postgres ishlatsangiz, connection string render tomonidan beriladi)
  - N8N_BASIC_AUTH_ACTIVE (true)
  - N8N_BASIC_AUTH_USER
  - N8N_BASIC_AUTH_PASSWORD
  - WEBHOOK_URL

- Agar siz Render Managed Postgres ishlatmoqchi bo'lsangiz: Render dashboard-da "Add Database -> PostgreSQL" qilishingiz va connection string-ni DATABASE_URL sifatida konfiguratsiyaga qo'yishingiz mumkin.

4) Deploy va test
- Service yaratgach, Render avtomatik deployni boshlaydi. Build loglarini kuzatib turing. Agar build muvaffaqiyatsiz bo'lsa, loglarni menga yuboring — men yordam beraman.
- Deploydan so'ng, WEBHOOK_URL (Render tomonidan taqdim etilgan URL yoki custom domain) dan n8n UI-ga kirish va Basic Auth bilan login qilish.

5) Qo'shimcha sozlamalar
- Agar siz background jobs / worker-lar ishlatmoqchi bo'lsangiz (ko'proq load bo'lsa), "n8n-worker" xizmatini faollashtiring va kerakli environment variables (DATABASE_URL) o'rnating.
- Webhooklar uchun public https URL zarur — Render avtomatik TLS beradi.

Xavfsizlik:
- Hech qachon haqiqiy parollarni public repo-ga commit qilmang. Har doim Render Secrets yoki boshqa secret manager ishlating.

Agar xohlasangiz, men hozir:
- ushbu fayllarni render-deploy branch-ga commit qildim (commit qilinmoqda). 
- keyingi qadam: Render dashboard-ga repo ulab, secrets qo'shishingiz va birinchi deployni bosishingiz — agar siz xohlasangiz, men deploy loglarini birga kuzatib yordam beraman.
