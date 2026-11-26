import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-kuaforum-demo-seed",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEMO_GATE = "kuaforum-demo-seed-v1";
const DEMO_PASSWORD = "KuaforumDemo2026!";
const accounts = [
  { key: "customer", email: "demo.customer@kuaforum.test", name: "Elif Yılmaz", accountType: "customer", isAdmin: false },
  { key: "employee", email: "demo.employee@kuaforum.test", name: "Zeynep Kaya", accountType: "employee", isAdmin: false },
  { key: "owner", email: "demo.owner@kuaforum.test", name: "Luna Studio", accountType: "business_owner", isAdmin: false },
  { key: "admin", email: "demo.admin@kuaforum.test", name: "Kuaförüm Ana Yönetici", accountType: "customer", isAdmin: true },
];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return Response.json({ error: "Method not allowed" }, { status: 405, headers: corsHeaders });
  if (req.headers.get("x-kuaforum-demo-seed") !== DEMO_GATE) {
    return Response.json({ error: "Demo seed access denied" }, { status: 403, headers: corsHeaders });
  }

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const secretMap = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
    const secret = secretMap.default ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !secret) throw new Error("Supabase server credentials are unavailable.");

    const admin = createClient(url, secret, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const listed = await admin.auth.admin.listUsers({ page: 1, perPage: 100 });
    if (listed.error) throw listed.error;
    const usersByEmail = new Map((listed.data.users ?? []).map((user) => [user.email?.toLowerCase(), user]));

    const ids: Record<string, string> = {};
    for (const account of accounts) {
      const existing = usersByEmail.get(account.email);
      const result = existing
        ? await admin.auth.admin.updateUserById(existing.id, {
            password: DEMO_PASSWORD,
            email_confirm: true,
            user_metadata: { full_name: account.name, demo_account: true },
          })
        : await admin.auth.admin.createUser({
            email: account.email,
            password: DEMO_PASSWORD,
            email_confirm: true,
            user_metadata: { full_name: account.name, demo_account: true },
          });
      if (result.error || !result.data.user) throw result.error ?? new Error("Demo user creation failed.");
      const user = result.data.user;
      ids[account.key] = user.id;
      const profile = await admin.from("profiles").upsert({
        id: user.id,
        full_name: account.name,
        email: account.email,
        account_type: account.accountType,
        is_admin: account.isAdmin,
        is_blocked: false,
      }, { onConflict: "id" });
      if (profile.error) throw profile.error;
    }

    const customerId = ids.customer;
    const employeeUserId = ids.employee;
    const ownerId = ids.owner;
    const adminId = ids.admin;

    let business = await admin.from("businesses").select("id").eq("owner_id", ownerId).maybeSingle();
    if (business.error) throw business.error;
    let businessId = business.data?.id as string | undefined;
    if (!businessId) {
      const inserted = await admin.from("businesses").insert({
        owner_id: ownerId,
        name: "Luna Studio",
        address: "Kayseri, Türkiye",
        status: "active",
        discover_enabled: true,
        discover_paid: true,
        appointment_interval_minutes: 30,
      }).select("id").single();
      if (inserted.error) throw inserted.error;
      businessId = inserted.data.id as string;
    } else {
      const updated = await admin.from("businesses").update({
        name: "Luna Studio",
        status: "active",
        discover_enabled: true,
        discover_paid: true,
      }).eq("id", businessId);
      if (updated.error) throw updated.error;
    }

    let employee = await admin.from("employees").select("id").eq("user_id", employeeUserId).eq("business_id", businessId).maybeSingle();
    if (employee.error) throw employee.error;
    let employeeId = employee.data?.id as string | undefined;
    if (!employeeId) {
      const inserted = await admin.from("employees").insert({
        business_id: businessId,
        user_id: employeeUserId,
        display_name: "Zeynep Kaya",
        is_active: true,
      }).select("id").single();
      if (inserted.error) throw inserted.error;
      employeeId = inserted.data.id as string;
    }

    let service = await admin.from("services").select("id").eq("business_id", businessId).eq("name", "Kesim & Fön").maybeSingle();
    if (service.error) throw service.error;
    let serviceId = service.data?.id as string | undefined;
    if (!serviceId) {
      const inserted = await admin.from("services").insert({
        business_id: businessId,
        name: "Kesim & Fön",
        price: 650,
        duration_minutes: 45,
        is_active: true,
      }).select("id").single();
      if (inserted.error) throw inserted.error;
      serviceId = inserted.data.id as string;
    }

    const photoUrls = [
      "https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=1000&q=82",
      "https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=1000&q=82",
    ];
    const mediaPaths: string[] = [];
    for (let i = 0; i < photoUrls.length; i++) {
      const path = `demo/${businessId}/style-${i + 1}.jpg`;
      const response = await fetch(photoUrls[i]);
      if (!response.ok) throw new Error("Demo salon photo could not be downloaded.");
      const bytes = new Uint8Array(await response.arrayBuffer());
      const uploaded = await admin.storage.from("salon-feed").upload(path, bytes, {
        contentType: "image/jpeg",
        upsert: true,
      });
      if (uploaded.error) throw uploaded.error;
      mediaPaths.push(path);
    }

    const ensurePost = async (authorId: string, employeeRef: string | null, caption: string, category: string, mediaPath: string) => {
      const found = await admin.from("feed_posts").select("id").eq("author_user_id", authorId).eq("caption", caption).maybeSingle();
      if (found.error) throw found.error;
      if (found.data?.id) return found.data.id as string;
      const inserted = await admin.from("feed_posts").insert({
        business_id: businessId,
        employee_id: employeeRef,
        author_user_id: authorId,
        caption,
        category,
        media_url: mediaPath,
        media_type: "image",
      }).select("id").single();
      if (inserted.error) throw inserted.error;
      return inserted.data.id as string;
    };

    const ownerPostId = await ensurePost(
      ownerId, null,
      "Luna Studio'da yeni sezonun ışıltılı dokunuşları ✨ Randevunu bekliyoruz.",
      "Genel", mediaPaths[0],
    );
    const employeePostId = await ensurePost(
      employeeUserId, employeeId,
      "Doğal geçişli, yumuşak tonlarda balayage çalışmamız. Nasıl buldunuz? 🤍",
      "Ombre", mediaPaths[1],
    );

    const followCheck = await admin.from("feed_follows").select("id").eq("follower_user_id", customerId).eq("followed_user_id", employeeUserId).maybeSingle();
    if (followCheck.error) throw followCheck.error;
    if (!followCheck.data) {
      const followed = await admin.from("feed_follows").insert({ follower_user_id: customerId, followed_user_id: employeeUserId });
      if (followed.error) throw followed.error;
    }
    const businessFollow = await admin.from("feed_follows").select("id").eq("follower_user_id", customerId).eq("followed_business_id", businessId).maybeSingle();
    if (businessFollow.error) throw businessFollow.error;
    if (!businessFollow.data) {
      const followed = await admin.from("feed_follows").insert({ follower_user_id: customerId, followed_business_id: businessId });
      if (followed.error) throw followed.error;
    }

    const membership = await admin.from("business_memberships").upsert({
      business_id: businessId,
      customer_id: customerId,
    }, { onConflict: "customer_id" });
    if (membership.error) throw membership.error;

    const conversation = await admin.from("conversations")
      .select("id")
      .eq("employee_id", employeeId)
      .eq("customer_id", customerId)
      .maybeSingle();
    if (conversation.error) throw conversation.error;
    let conversationId = conversation.data?.id as string | undefined;
    if (!conversationId) {
      const inserted = await admin.from("conversations").insert({
        business_id: businessId,
        employee_id: employeeId,
        customer_id: customerId,
        source_post_id: employeePostId,
      }).select("id").single();
      if (inserted.error) throw inserted.error;
      conversationId = inserted.data.id as string;
    }
    const messageCheck = await admin.from("messages").select("id").eq("conversation_id", conversationId).limit(1);
    if (messageCheck.error) throw messageCheck.error;
    if ((messageCheck.data ?? []).length === 0) {
      const inserted = await admin.from("messages").insert([
        { conversation_id: conversationId, sender_id: customerId, body: "Merhaba Zeynep, balayage için uygun randevunuz var mı?" },
        { conversation_id: conversationId, sender_id: employeeUserId, body: "Merhaba Elif! Elbette, bu hafta birkaç uygun saatimiz var. Saç uzunluğunu da konuşabiliriz. 🌸" },
        { conversation_id: conversationId, sender_id: customerId, body: "Harika, teşekkür ederim. Cuma günü görüşmek üzere!" },
      ]);
      if (inserted.error) throw inserted.error;
    }

    const appointmentCheck = await admin.from("appointments").select("id").eq("customer_id", customerId).eq("business_id", businessId).limit(1);
    if (appointmentCheck.error) throw appointmentCheck.error;
    if ((appointmentCheck.data ?? []).length === 0) {
      const startsAt = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000);
      startsAt.setHours(14, 0, 0, 0);
      const endsAt = new Date(startsAt.getTime() + 45 * 60 * 1000);
      const inserted = await admin.from("appointments").insert({
        business_id: businessId,
        customer_id: customerId,
        employee_id: employeeId,
        service_id: serviceId,
        starts_at: startsAt.toISOString(),
        ends_at: endsAt.toISOString(),
        status: "confirmed",
        customer_note: "Demo randevu kaydı",
      });
      if (inserted.error) throw inserted.error;
    }

    const commentCheck = await admin.from("feed_comments").select("id").eq("post_id", employeePostId).eq("user_id", customerId).limit(1);
    if (commentCheck.error) throw commentCheck.error;
    if ((commentCheck.data ?? []).length === 0) {
      const comment = await admin.from("feed_comments").insert({
        post_id: employeePostId,
        user_id: customerId,
        body: "Renk geçişi harika olmuş! 🤍",
        author_name: "Elif Yılmaz",
      });
      if (comment.error) throw comment.error;
    }
    const like = await admin.from("feed_likes").upsert({
      post_id: employeePostId,
      user_id: customerId,
    }, { onConflict: "post_id,user_id", ignoreDuplicates: true });
    if (like.error) throw like.error;

    const notificationCheck = await admin.from("notifications").select("id").eq("user_id", customerId).limit(1);
    if (notificationCheck.error) throw notificationCheck.error;
    if ((notificationCheck.data ?? []).length === 0) {
      const notification = await admin.from("notifications").insert({
        user_id: customerId,
        title: "Randevun onaylandı",
        body: "Luna Studio • Kesim & Fön randevun oluşturuldu.",
      });
      if (notification.error) throw notification.error;
    }

    return Response.json({
      ok: true,
      accounts: Object.fromEntries(accounts.map((account) => [account.key, account.email])),
      seeded: { businessId, employeeId, ownerPostId, employeePostId, conversationId },
    }, { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    console.error("Kuaforum demo seed failed", error);
    return Response.json({
      error: error instanceof Error ? error.message : "Demo data could not be prepared.",
    }, { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
