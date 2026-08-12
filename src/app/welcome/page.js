"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";
import Navbar from "@/app/components/Navbar";
import Footer from "@/app/components/Footer";

const GOOGLE_REGISTER_ROLE_KEY = "googleRegisterRole";
const GOOGLE_REGISTER_ROLE_MAX_AGE_MS = 10 * 60 * 1000;

function readAndClearGoogleRegisterRole() {
  const raw = localStorage.getItem(GOOGLE_REGISTER_ROLE_KEY);
  localStorage.removeItem(GOOGLE_REGISTER_ROLE_KEY);

  if (!raw) {
    return null;
  }

  try {
    const parsed = JSON.parse(raw);

    if (
      parsed?.role &&
      typeof parsed.ts === "number" &&
      Date.now() - parsed.ts < GOOGLE_REGISTER_ROLE_MAX_AGE_MS
    ) {
      return parsed.role;
    }
  } catch {
    // malformed value, ignore
  }

  return null;
}

export default function WelcomePage() {
  const router = useRouter();
  const [profileErrorMessage, setProfileErrorMessage] = useState("");

  async function completeProfile() {
    const { data: userData, error: userError } = await supabase.auth.getUser();

    if (userError || !userData?.user) {
      router.push("/login");
      return;
    }

    const user = userData.user;

    const { data: existingProfile, error: fetchError } = await supabase
      .from("profiles")
      .select("id")
      .eq("id", user.id)
      .maybeSingle();

    if (fetchError) {
      console.error("Profile lookup error:", fetchError.message);
      setProfileErrorMessage(
        "We couldn't finish setting up your account. Please refresh this page or contact support."
      );
      return;
    }

    if (existingProfile) {
      localStorage.removeItem(GOOGLE_REGISTER_ROLE_KEY);
      return;
    }

    const role =
      readAndClearGoogleRegisterRole() ||
      user.user_metadata?.role ||
      "Free";

    const fullName =
      user.user_metadata?.full_name ||
      user.user_metadata?.name ||
      user.email?.split("@")[0] ||
      "User";

    const { error: profileError } = await supabase.from("profiles").insert({
      id: user.id,
      full_name: fullName,
      email: user.email,
      user_type: role,
      status: "active",
    });

    if (profileError) {
      console.error("Profile save error:", profileError.message);
      setProfileErrorMessage(
        "We couldn't finish setting up your account. Please refresh this page or contact support."
      );
      return;
    }

    await supabase.auth.updateUser({
      data: {
        full_name: fullName,
        role,
      },
    });
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- setState calls happen after network awaits, not synchronously
    completeProfile();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- intentionally run once on mount
  }, []);

  return (
    <main className="min-h-screen bg-[#f8f8ff] text-black">
      <Navbar />

      {profileErrorMessage && (
        <div className="bg-red-50 border-b border-red-200 text-red-700 text-[14px] text-center px-6 py-3">
          {profileErrorMessage}
        </div>
      )}

      {/* Welcome Content */}
      <section className="min-h-[480px] flex items-center justify-center px-10 md:px-12 py-20">
        <div className="w-full max-w-[960px] grid grid-cols-1 md:grid-cols-2 gap-16 items-center">
          {/* Left Text */}
          <div>
            <h1 className="text-[30px] md:text-[32px] font-bold">
              Welcome to ShapeRush! 🎉
            </h1>

            <p className="mt-6 text-[17px] leading-7 text-gray-500 max-w-[460px]">
              Your account has been created successfully.
              <br />
              Download the app and start your fitness journey.
            </p>
          </div>

          {/* APK Download Card */}
          <div className="flex justify-center md:justify-end">
            <div className="w-full max-w-[315px] bg-white rounded-[20px] shadow-sm px-8 py-8 text-center">
              <div className="flex justify-center">
                <AndroidIcon />
              </div>

              <h2 className="mt-5 text-[22px] font-bold">Download APK</h2>

              <p className="mt-5 text-[14px] leading-6 text-gray-500">
                Download our Android APK file and install it manually.
              </p>

              <a
                href="https://github.com/Tiarasxm/FYP/releases/latest/download/ShapeRush.apk"
                target="_blank"
                rel="noopener noreferrer"
                className="mt-8 w-full h-[44px] bg-[#6c5cff] text-white rounded-lg text-[13px] font-semibold flex items-center justify-center gap-3 hover:bg-[#5b4bea]"
              >
                Download APK
                <DownloadIcon />
              </a>
            </div>
          </div>
        </div>
      </section>

      <Footer />
    </main>
  );
}

function AndroidIcon() {
  return (
    <svg
      width="62"
      height="62"
      viewBox="0 0 64 64"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M20 27C20 20.4 25.4 15 32 15C38.6 15 44 20.4 44 27V43C44 46.3 41.3 49 38 49H26C22.7 49 20 46.3 20 43V27Z"
        fill="#7ED321"
      />
      <path
        d="M17 29C15.3 29 14 30.3 14 32V42C14 43.7 15.3 45 17 45C18.7 45 20 43.7 20 42V32C20 30.3 18.7 29 17 29Z"
        fill="#7ED321"
      />
      <path
        d="M47 29C45.3 29 44 30.3 44 32V42C44 43.7 45.3 45 47 45C48.7 45 50 43.7 50 42V32C50 30.3 48.7 29 47 29Z"
        fill="#7ED321"
      />
      <path
        d="M26 49V55"
        stroke="#7ED321"
        strokeWidth="6"
        strokeLinecap="round"
      />
      <path
        d="M38 49V55"
        stroke="#7ED321"
        strokeWidth="6"
        strokeLinecap="round"
      />
      <path
        d="M25 12L21 7"
        stroke="#7ED321"
        strokeWidth="3"
        strokeLinecap="round"
      />
      <path
        d="M39 12L43 7"
        stroke="#7ED321"
        strokeWidth="3"
        strokeLinecap="round"
      />
      <circle cx="27" cy="25" r="2" fill="white" />
      <circle cx="37" cy="25" r="2" fill="white" />
    </svg>
  );
}

function DownloadIcon() {
  return (
    <svg
      width="15"
      height="15"
      viewBox="0 0 24 24"
      fill="none"
      stroke="white"
      strokeWidth="2.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M12 3v12" />
      <path d="m7 10 5 5 5-5" />
      <path d="M5 21h14" />
    </svg>
  );
}