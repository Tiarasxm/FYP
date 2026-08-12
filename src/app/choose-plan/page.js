"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import Navbar from "@/app/components/Navbar";
import { defaultSubscription } from "@/lib/defaultWebsiteContent";

function getPlanKind(title) {
  const normalized = (title || "").trim().toLowerCase();

  if (normalized === "free") {
    return "free";
  }

  if (normalized === "priority") {
    return "priority";
  }

  return null;
}

export default function ChoosePlanPage() {
  const router = useRouter();
  const [subscription, setSubscription] = useState(defaultSubscription);
  const [contentLoading, setContentLoading] = useState(true);
  const [selected, setSelected] = useState("free");
  const [loading, setLoading] = useState(false);

  async function fetchSubscriptionContent() {
    const { data, error } = await supabase
      .from("website_content")
      .select("content")
      .eq("section_key", "subscription")
      .maybeSingle();

    if (error) {
      console.error("Fetch subscription content error:", error.message);
    }

    setSubscription(data?.content || defaultSubscription);
    setContentLoading(false);
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- setState calls happen after network awaits, not synchronously
    fetchSubscriptionContent();
  }, []);

  async function handleContinue() {
    setLoading(true);

    const { data: userData, error: userError } = await supabase.auth.getUser();

    if (userError || !userData?.user) {
      router.replace("/login");
      return;
    }

    if (selected === "priority") {
      const { data: profileRows, error: profileError } = await supabase
        .from("profiles")
        .update({ user_type: "Priority" })
        .eq("id", userData.user.id)
        .select();

      if (profileError) {
        alert(profileError.message);
        setLoading(false);
        return;
      }

      if (!profileRows || profileRows.length === 0) {
        alert(
          "Failed to update your plan. Please try again or contact support."
        );
        setLoading(false);
        return;
      }

      const now = new Date();
      const expiresAt = new Date(now);
      expiresAt.setMonth(expiresAt.getMonth() + 1);
      const { data: priorityRows, error: priorityError } = await supabase
        .from("priority_user")
        .upsert(
          {
            profile_id: userData.user.id,
            subscribed_at: now.toISOString(),
            expires_at: expiresAt.toISOString(),
          },
          { onConflict: "profile_id" }
        )
        .select();

      if (priorityError) {
        alert(priorityError.message);
        setLoading(false);
        return;
      }

      if (!priorityRows || priorityRows.length === 0) {
        alert(
          "Failed to activate your priority subscription. Please try again or contact support."
        );
        setLoading(false);
        return;
      }
    }

    router.push("/welcome");
  }

  return (
    <main className="min-h-screen bg-[#f8f8ff] text-black flex flex-col">
      <Navbar />

      {/* Plan selection */}
      <section className="relative overflow-hidden flex-1 bg-[#fafaff] px-10 md:px-24 py-24">
        <h1 className="absolute bottom-[-38px] left-0 right-0 text-[150px] md:text-[180px] font-bold text-[#ececf7] z-0 text-center leading-none">
          ShapeRush
        </h1>

        <div className="relative z-10 text-center">
          <p className="text-[#6c5cff] text-[13px] font-semibold uppercase">
            Subscription Plans
          </p>

          <h2 className="text-[24px] font-bold mt-2">
            Choose a plan to continue
          </h2>

          {contentLoading ? (
            <p className="mt-12 text-gray-500">Loading plans...</p>
          ) : (
            <div className="mt-12 flex flex-col md:flex-row justify-center gap-8">
              {(subscription.plans || []).map((plan, index) => {
                const kind = getPlanKind(plan.title);
                const id = kind || `plan-${index}`;
                const premium = kind === "priority";

                return (
                  <button
                    key={id}
                    type="button"
                    onClick={() => setSelected(id)}
                    className={`w-[310px] min-h-[390px] bg-white rounded-[22px] p-8 text-left transition-all ${
                      selected === id
                        ? "border-2 border-[#6c5cff] shadow-md"
                        : premium
                        ? "border-2 border-gray-200"
                        : "border-2 border-transparent"
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <h3 className="text-[22px] font-bold">{plan.title}</h3>
                      {selected === id && (
                        <span className="w-5 h-5 rounded-full bg-[#6c5cff] flex items-center justify-center">
                          <CheckIcon />
                        </span>
                      )}
                    </div>

                    <p className="mt-3 text-[12px] leading-5 text-gray-500">
                      {plan.description}
                    </p>

                    <div className="mt-10 flex items-end">
                      <p className="text-[32px] font-medium">{plan.price}</p>
                      {premium && (
                        <span className="ml-2 mb-2 text-gray-500">/month</span>
                      )}
                    </div>

                    <div className="h-px bg-gray-200 my-5" />

                    <ul className="space-y-4 text-[13px]">
                      {(plan.features || []).map((feature, i) => (
                        <li key={i} className="flex items-center gap-3">
                          <TickIcon />
                          <span>{feature}</span>
                        </li>
                      ))}
                    </ul>
                  </button>
                );
              })}
            </div>
          )}

          <button
            type="button"
            onClick={handleContinue}
            disabled={loading || contentLoading}
            className="mt-12 px-14 h-[48px] bg-[#6c5cff] text-white rounded-xl text-[14px] font-semibold hover:bg-[#5b4bea] disabled:opacity-60"
          >
            {loading ? "Please wait..." : "Continue"}
          </button>
        </div>
      </section>
    </main>
  );
}

function CheckIcon() {
  return (
    <svg
      width="12"
      height="12"
      viewBox="0 0 24 24"
      fill="none"
      stroke="white"
      strokeWidth="3"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}

function TickIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#6c5cff"
      strokeWidth="2.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      className="shrink-0"
    >
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}
