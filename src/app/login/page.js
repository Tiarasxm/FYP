"use client";

import Link from "next/link";
import Image from "next/image";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import Navbar from "@/app/components/Navbar";

export default function LoginPage() {
  const router = useRouter();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [emailError, setEmailError] = useState("");
  const [loading, setLoading] = useState(false);

  function isCorrectEmailFormat(value) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
  }

  function handleEmailChange(event) {
    const value = event.target.value;
    setEmail(value);
    if (value && !isCorrectEmailFormat(value)) {
      setEmailError("Please enter your correct email");
    } else {
      setEmailError("");
    }
  }

  async function handleLogin(event) {
    event.preventDefault();

    if (!isCorrectEmailFormat(email)) {
      setEmailError("Please enter your correct email");
      return;
    }

    if (password.length < 8) {
      alert("Password must be at least 8 characters.");
      return;
    }

    setLoading(true);

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      alert(error.message);
      setLoading(false);
      return;
    }

    await redirectByUserType(data.user.id);
  }

  async function handleGoogleLogin() {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}/login/callback`,
      },
    });

    if (error) {
      alert(error.message);
    }
  }

  async function redirectByUserType(userId) {

    // Check if admin first
    const { data: adminRow } = await supabase
      .from("admin")
      .select("profile_id")
      .eq("profile_id", userId)
      .single();
    if (adminRow) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("email, status")
        .eq("id", userId)
        .single();
      if (profile?.status !== "active") {
        alert("This admin account is not active.");
        await supabase.auth.signOut();
        setLoading(false);
        return;
      }
      localStorage.setItem("adminLoggedIn", "true");
      localStorage.setItem("adminEmail", profile.email || "");
      router.push("/admin/dashboard");
      return;
    }

    const { data: profile, error } = await supabase
      .from("profiles")
      .select("user_type, status")
      .eq("id", userId)
      .single();

    if (error || !profile) {
      alert("Account not found. Please register first.");
      await supabase.auth.signOut();
      setLoading(false);
      return;
    }

    const normalizedStatus = (profile.status || "").trim().toLowerCase();

    if (normalizedStatus === "suspended") {
      alert("This account has been restricted. Please contact support.");
      await supabase.auth.signOut();
      setLoading(false);
      return;
    }

    if (normalizedStatus === "deleted") {
      alert("This account has been deactivated.");
      await supabase.auth.signOut();
      setLoading(false);
      return;
    }

    const type = profile.user_type;

    if (normalizedStatus === "incomplete" && type === "Fitness professional") {
      router.push("/fitness-profile");
      return;
    }

    if (type === "Free") {
      router.push("/choose-plan");
    } else {
      router.push("/welcome");
    }
  }

  return (
    <main className="min-h-screen bg-[#f8f8ff] text-black flex flex-col">
      <Navbar />

      {/* Login Form */}
      <section className="flex-1 flex items-center justify-center px-6 py-16">
        <div className="w-full max-w-[420px]">
          <h1 className="text-[26px] font-bold">Welcome back</h1>
          <p className="mt-2 text-[14px] text-gray-500">
            Log in to your ShapeRush account
          </p>

          <form onSubmit={handleLogin} className="mt-8 space-y-4">
            <div>
              <label className="block text-[13px] font-medium mb-1">
                Email
              </label>
              <input
                type="email"
                value={email}
                onChange={handleEmailChange}
                placeholder="Enter your email"
                className="w-full h-[46px] border border-gray-300 rounded-lg px-4 text-[14px] outline-none focus:border-[#6c5cff]"
              />
              {emailError && (
                <p className="mt-1 text-[12px] text-red-500">{emailError}</p>
              )}
            </div>

            <div>
              <label className="block text-[13px] font-medium mb-1">
                Password
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Enter your password"
                className="w-full h-[46px] border border-gray-300 rounded-lg px-4 text-[14px] outline-none focus:border-[#6c5cff]"
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full h-[46px] bg-[#6c5cff] text-white rounded-lg text-[14px] font-semibold hover:bg-[#5b4bea] disabled:opacity-60"
            >
              {loading ? "Logging in..." : "Log In"}
            </button>
          </form>

          <div className="flex items-center gap-4 my-6">
            <div className="flex-1 h-px bg-gray-200" />
            <span className="text-[13px] text-gray-400">or</span>
            <div className="flex-1 h-px bg-gray-200" />
          </div>

          <button
            type="button"
            onClick={handleGoogleLogin}
            className="w-full h-[46px] border border-gray-300 rounded-lg flex items-center justify-center gap-3 text-[14px] font-semibold text-gray-700 bg-white hover:bg-gray-50"
          >
            <Image
              src="/images/google.png"
              alt="Google"
              width={22}
              height={22}
              className="object-contain"
            />
            Continue with Google
          </button>

          <p className="mt-8 text-center text-[13px] text-gray-500">
            Don&apos;t have an account?{" "}
            <Link href="/register" className="text-[#6c5cff] font-semibold">
              Register
            </Link>
          </p>
        </div>
      </section>
    </main>
  );
}
