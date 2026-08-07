"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function LoginCallbackPage() {
  const router = useRouter();

  async function handleCallback() {
    const { data, error } = await supabase.auth.getUser();

    if (error || !data?.user) {
      router.replace("/login");
      return;
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("user_type")
      .eq("id", data.user.id)
      .single();

    if (profileError || !profile) {
      router.replace("/welcome");
      return;
    }

    if (profile.user_type === "Free") {
      router.replace("/choose-plan");
    } else {
      router.replace("/welcome");
    }
  }

  useEffect(() => {
    handleCallback();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- intentionally run once on mount
  }, []);

  return (
    <main className="min-h-screen bg-[#f8f8ff] flex items-center justify-center">
      <p className="text-gray-500 text-[14px]">Signing you in...</p>
    </main>
  );
}
