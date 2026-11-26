import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders });
  }

  const json = (body: Record<string, unknown>, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) return json({ error: "Oturum doğrulanamadı." }, 401);
    const token = authHeader.slice("Bearer ".length);
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) return json({ error: "Sunucu yapılandırması eksik." }, 500);

    const admin = createClient(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) return json({ error: "Oturum geçersiz veya süresi dolmuş." }, 401);
    const ownerId = authData.user.id;

    const body = await req.json();
    const businessId = String(body.business_id ?? "").trim();
    const firstName = String(body.first_name ?? "").trim();
    const lastName = String(body.last_name ?? "").trim();
    const phone = String(body.phone ?? "").trim();
    const email = String(body.email ?? "").trim().toLowerCase();
    const password = String(body.password ?? "");

    if (!businessId || !firstName || !lastName || !phone || !email || !password) {
      return json({ error: "Ad, soyad, telefon, e-posta ve şifre zorunludur." }, 400);
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json({ error: "Geçerli bir e-posta adresi girin." }, 400);
    }
    if (password.length < 8) return json({ error: "Şifre en az 8 karakter olmalıdır." }, 400);
    if (phone.replace(/\D/g, "").length < 10) return json({ error: "Geçerli bir telefon numarası girin." }, 400);

    const { data: profile, error: profileError } = await admin
      .from("profiles").select("account_type,is_blocked").eq("id", ownerId).single();
    if (profileError || profile.account_type !== "business_owner" || profile.is_blocked) {
      return json({ error: "Bu işlem yalnızca aktif işletme sahibi tarafından yapılabilir." }, 403);
    }

    const { data: business, error: businessError } = await admin
      .from("businesses").select("id").eq("id", businessId)
      .eq("owner_id", ownerId).eq("status", "active").maybeSingle();
    if (businessError || !business) return json({ error: "Bu işletmede çalışan ekleme yetkiniz yok." }, 403);

    const fullName = `${firstName} ${lastName}`;
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: fullName, first_name: firstName, last_name: lastName, phone, account_type: "employee" },
    });
    if (inviteError || !invited.user) {
      return json({ error: inviteError?.message ?? "Davet e-postası gönderilemedi." }, 400);
    }

    const employeeUserId = invited.user.id;
    try {
      const { error: passwordError } = await admin.auth.admin.updateUserById(employeeUserId, { password });
      if (passwordError) throw passwordError;

      const { error: updateProfileError } = await admin.from("profiles").update({
        full_name: fullName, email, phone, account_type: "employee",
      }).eq("id", employeeUserId);
      if (updateProfileError) throw updateProfileError;

      const { error: employeeError } = await admin.from("employees").insert({
        business_id: businessId, user_id: employeeUserId, display_name: fullName, is_active: true,
      });
      if (employeeError) throw employeeError;
    } catch (error) {
      await admin.auth.admin.deleteUser(employeeUserId);
      throw error;
    }

    return json({ success: true, employee_id: employeeUserId });
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Çalışan hesabı oluşturulamadı." }, 400);
  }
});
