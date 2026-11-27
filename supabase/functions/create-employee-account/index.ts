import { withSupabase } from "npm:@supabase/server@1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (error && typeof error === "object") {
    const value = error as Record<string, unknown>;
    for (const key of ["message", "details", "hint"]) {
      if (typeof value[key] === "string" && value[key]) return value[key] as string;
    }
  }
  return "Çalışan hesabı oluşturulamadı.";
}

const authenticatedHandler = withSupabase({ auth: "user" }, async (req, ctx) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const admin = ctx.supabaseAdmin;
  const ownerId = String(ctx.userClaims?.sub ?? "");
  if (!ownerId) return json({ error: "Oturum doğrulanamadı." }, 401);

  try {
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
    if (email === "gazitasdemir56@gmail.com") {
      return json({ error: "Bu e-posta ana yönetici hesabına ayrılmıştır." }, 409);
    }
    if (password.length < 8) return json({ error: "Şifre en az 8 karakter olmalıdır." }, 400);
    if (phone.replace(/\D/g, "").length < 10) {
      return json({ error: "Geçerli bir telefon numarası girin." }, 400);
    }

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("account_type,is_blocked")
      .eq("id", ownerId)
      .single();

    if (profileError || profile?.account_type !== "business_owner" || profile?.is_blocked) {
      return json({ error: "Bu işlem yalnızca aktif işletme sahibi tarafından yapılabilir." }, 403);
    }

    const { data: business, error: businessError } = await admin
      .from("businesses")
      .select("id")
      .eq("id", businessId)
      .eq("owner_id", ownerId)
      .eq("status", "active")
      .maybeSingle();

    if (businessError || !business) {
      return json({ error: "Bu işletmede çalışan ekleme yetkiniz yok." }, 403);
    }

    const fullName = `${firstName} ${lastName}`;

    // Create the account directly as confirmed; no invitation or email verification step.
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: fullName,
        first_name: firstName,
        last_name: lastName,
        phone,
        account_type: "employee",
      },
    });

    if (createError || !created.user) {
      const message = createError ? getErrorMessage(createError) : "Çalışan hesabı oluşturulamadı.";
      const status = /already|exists|registered|duplicate/i.test(message) ? 409 : 400;
      return json({ error: message }, status);
    }

    const employeeUserId = created.user.id;
    try {
      const { data: updatedProfile, error: updateProfileError } = await admin
        .from("profiles")
        .update({ full_name: fullName, email, phone, account_type: "employee" })
        .eq("id", employeeUserId)
        .select("id")
        .maybeSingle();

      if (updateProfileError) throw updateProfileError;
      if (!updatedProfile) throw new Error("Çalışan profili oluşturulamadı.");

      const { error: employeeError } = await admin.from("employees").insert({
        business_id: businessId,
        user_id: employeeUserId,
        display_name: fullName,
        is_active: true,
      });
      if (employeeError) throw employeeError;
    } catch (error) {
      const { error: deleteError } = await admin.auth.admin.deleteUser(employeeUserId);
      if (deleteError) console.error("Çalışan hesabı geri alınamadı:", getErrorMessage(deleteError));
      throw error;
    }

    return json({ success: true, employee_id: employeeUserId, email_confirmed: true });
  } catch (error) {
    console.error("create-employee-account:", getErrorMessage(error));
    return json({ error: getErrorMessage(error) }, 400);
  }
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const response = await authenticatedHandler(req);
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) headers.set(key, value);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
});
