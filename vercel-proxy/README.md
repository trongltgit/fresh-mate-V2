# FreshMate proxy on Vercel (alternative to Cloudflare)

In a cmd window opened inside this folder:

    npx vercel login
    npx vercel --prod
    npx vercel env add GROQ_API_KEY production
    npx vercel env add APP_TOKEN production
    npx vercel --prod

Your URL is  https://<project-name>.vercel.app/api/ai
Put it in src/proxy_config.h (FRESHMATE_PROXY_URL) with the same APP_TOKEN.
