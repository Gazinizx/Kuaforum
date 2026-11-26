import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const respond = (body: Record<string, unknown>, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  if (req.method !== "POST") return respond({ error: "Method not allowed" }, 405);

  try {
    const header = req.headers.get("Authorization");
    if (!header?.startsWith("Bearer ")) return respond({ error: "Oturum doğrulanamadı." }, 401);
    const token = header.slice(7);
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ??
      (Deno.env.get("SUPABASE_PUBLISHABLE_KEYS")
        ? JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS")!).default
        : undefined);
    if (!url || !serviceKey || !anonKey) return respond({ error: "Sunucu yapılandırması eksik." }, 500);

    const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { data: auth, error: authError } = await admin.auth.getUser(token);
    if (authError || !auth.user?.email) return respond({ error: "Oturum geçersiz." }, 401);

    const body = await req.json();
    const password = String(body.password ?? "");
    if (!password) return respond({ error: "Hesabını silmek için mevcut şifreni gir." }, 400);

    const { data: profile, error: profileError } = await admin.from("profiles")
      .select("account_type,is_admin,avatar_url").eq("id", auth.user.id).single();
    if (profileError || profile.account_type !== "customer" || profile.is_admin) {
      return respond({ error: "Bu işlem yalnızca müşteri hesapları için kullanılabilir." }, 403);
    }

    const verifier = createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false } });
    const { error: passwordError } = await verifier.auth.signInWithPassword({
      email: auth.user.email, password,
    });
    if (passwordError) return respond({ error: "Mevcut şifre doğru değil." }, 401);

    // Revoke refresh tokens across the user's sessions before deletion.
    await verifier.auth.signOut({ scope: "global" });

    const avatarUrl = profile.avatar_url as string | null;
    const marker = "/storage/v1/object/public/salon-avatars/";
    if (avatarUrl?.includes(marker)) {
      const objectPath = decodeURIComponent(avatarUrl.split(marker)[1] ?? "");
      if (objectPath.startsWith(`profiles/${auth.user.id}/`)) {
        try { await admin.storage.from("salon-avatars").remove([objectPath]); } catch (_) {}
      }
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(auth.user.id);
    if (deleteError) return respond({ error: deleteError.message }, 400);
    return respond({ success: true });
  } catch (error) {
    return respond({ error: error instanceof Error ? error.message : "Hesap silinemedi." }, 400);
  }
});
