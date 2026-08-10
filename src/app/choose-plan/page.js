"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import Navbar from "@/app/components/Navbar";

const plans = [
  {
    id: "free",
    title: "Free",
    price: "$0",
    description:
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
    features: [
      "Basic workouts",
      "Workout tracking",
      "Community Access",
      "Workout tracking",
    ],
    premium: false,
  },
  {
    id: "priority",
    title: "Priority",
    price: "$7.99",
    description:
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
    features: [
      "Workout tracking",
      "Basic workouts",
      "Workout tracking",
      "Basic workouts",
      "Workout tracking",
      "Basic workouts",
    ],
    premium: true,
  },
];

export default function ChoosePlanPage() {
  const router = useRouter();
  const [selected, setSelected] = useState("free");
  const [loading, setLoading] = useState(false);

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

          <div className="mt-12 flex flex-col md:flex-row justify-center gap-8">
            {plans.map((plan) => (
              <button
                key={plan.id}
                type="button"
                onClick={() => setSelected(plan.id)}
                className={`w-[310px] min-h-[390px] bg-white rounded-[22px] p-8 text-left transition-all ${
                  selected === plan.id
                    ? "border-2 border-[#6c5cff] shadow-md"
                    : plan.premium
                    ? "border-2 border-gray-200"
                    : "border-2 border-transparent"
                }`}
              >
                <div className="flex items-center justify-between">
                  <h3 className="text-[22px] font-bold">{plan.title}</h3>
                  {selected === plan.id && (
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
                  {plan.premium && (
                    <span className="ml-2 mb-2 text-gray-500">/month</span>
                  )}
                </div>

                <div className="h-px bg-gray-200 my-5" />

                <ul className="space-y-4 text-[13px]">
                  {plan.features.map((feature, i) => (
                    <li key={i} className="flex items-center gap-3">
                      <TickIcon />
                      <span>{feature}</span>
                    </li>
                  ))}
                </ul>
              </button>
            ))}
          </div>

          <button
            type="button"
            onClick={handleContinue}
            disabled={loading}
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
