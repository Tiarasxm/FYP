"use client";

import Link from "next/link";
import Image from "next/image";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

export default function RegisterPage() {
  const router = useRouter();

  const [role, setRole] = useState("client");
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const [emailError, setEmailError] = useState("");

  function isCorrectEmailFormat(emailValue) {
    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailPattern.test(emailValue);
  }

  function handleEmailChange(event) {
    const newEmail = event.target.value;
    setEmail(newEmail);

    if (newEmail === "") {
      setEmailError("");
      return;
    }

    if (!isCorrectEmailFormat(newEmail)) {
      setEmailError("Please enter your correct email");
    } else {
      setEmailError("");
    }
  }

  async function handleCreateAccount(event) {
    event.preventDefault();

    if (!fullName.trim()) {
      alert("Please enter your full name.");
      return;
    }

    if (!isCorrectEmailFormat(email)) {
      setEmailError("Please enter your correct email");
      return;
    }

    if (password.length < 8) {
      alert("Password must be at least 8 characters.");
      return;
    }

    const redirectPath =
      role === "fitness_professional" ? "/fitness-profile" : "/welcome";

    const databaseRole =
      role === "fitness_professional" ? "Fitness professional" : "Free";

    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: fullName,
          role: databaseRole,
        },
        emailRedirectTo: `${window.location.origin}${redirectPath}`,
      },
    });

    if (error) {
      alert(error.message);
      return;
    }

    router.push(`/check-email?email=${encodeURIComponent(email)}`);
  }

  async function handleGoogleRegister() {
    const redirectPath =
      role === "fitness_professional" ? "/fitness-profile" : "/welcome";

    const databaseRole =
      role === "fitness_professional" ? "Fitness professional" : "Free";

    localStorage.setItem(
      "googleRegisterRole",
      JSON.stringify({ role: databaseRole, ts: Date.now() })
    );
  
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: `${window.location.origin}${redirectPath}`,
      },
    });

    if (error) {
      alert(error.message);
    }
  }

  return (
    <main className="min-h-screen bg-[#f8f8ff] text-black">
      {/* Navbar */}
      <nav className="sticky top-0 z-50 h-[78px] bg-white flex items-center justify-between px-10 md:px-12 shadow-sm">
        <Link href="/" className="text-[22px] font-bold tracking-tight">
          ShapeRush
        </Link>

        <div className="hidden md:flex items-center gap-9 text-[13px] font-medium">
          <Link href="/">Home</Link>
          <Link href="/#features">Features</Link>
          <Link href="/#plans">Plans</Link>
          <Link href="/#reviews">Reviews</Link>
          <Link href="/#faq">FAQ</Link>
        </div>

        <Link
          href="/register"
          className="bg-[#6c5cff] text-white px-8 py-3 rounded-xl text-[13px] font-semibold"
        >
          Register
        </Link>
      </nav>

      {/* Register Content */}
      <section className="min-h-[760px] flex items-center justify-center px-6 py-16">
        <div className="w-full max-w-[420px] bg-white rounded-[22px] shadow-sm px-12 py-12">
          <div className="text-center">
            <h1 className="text-[22px] font-bold">Create your account</h1>

            <p className="mt-3 text-[14px] font-semibold text-gray-500">
              Start your fitness journey today.
            </p>
          </div>

          {/* Google Register Button */}
          <button
            type="button"
            onClick={handleGoogleRegister}
            className="mt-9 w-full h-[46px] border border-gray-300 rounded-lg flex items-center justify-center gap-3 text-[14px] font-semibold text-gray-700 bg-white hover:bg-gray-50"
          >
            <Image
              src="/images/google.png"
              alt="Google"
              width={28}
              height={28}
              className="object-contain"
            />
            <span>Continue with Google</span>
          </button>

          <div className="flex items-center gap-4 my-8">
            <div className="h-px bg-gray-200 flex-1" />
            <span className="text-[13px] text-gray-500">or</span>
            <div className="h-px bg-gray-200 flex-1" />
          </div>

          <form onSubmit={handleCreateAccount}>
            {/* Role Selection */}
            <div className="mb-7">
              <label className="block text-[14px] font-bold mb-3">
                Create Account As
              </label>

              <div className="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  onClick={() => {
                    setRole("client");
                    setFullName("");
                    setEmail("");
                    setPassword("");
                    setEmailError("");
                  }}
                  className={`h-[64px] rounded-lg border-2 flex flex-col items-center justify-center gap-1 text-[13px] font-semibold transition-colors ${
                    role === "client"
                      ? "border-[#6c5cff] bg-[#f0eeff] text-[#6c5cff]"
                      : "border-gray-200 text-gray-600 hover:border-gray-300"
                  }`}
                >
                  <UserIcon />
                  Client
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setRole("fitness_professional");
                    setFullName("");
                    setEmail("");
                    setPassword("");
                    setEmailError("");
                  }}
                  className={`h-[64px] rounded-lg border-2 flex flex-col items-center justify-center gap-1 text-[13px] font-semibold transition-colors ${
                    role === "fitness_professional"
                      ? "border-[#6c5cff] bg-[#f0eeff] text-[#6c5cff]"
                      : "border-gray-200 text-gray-600 hover:border-gray-300"
                  }`}
                >
                  <FitnessIcon />
                  Fitness Professional
                </button>
              </div>
            </div>

            {/* Full Name */}
            <div className="mb-7">
              <label className="block text-[14px] font-bold mb-3">
                Full Name<span className="text-red-500">*</span>
              </label>

              <div className="h-[48px] border border-gray-300 rounded-lg flex items-center px-4 gap-3">
                <UserIcon />

                <input
                  type="text"
                  value={fullName}
                  onChange={(event) => setFullName(event.target.value)}
                  placeholder="Enter your full name"
                  required
                  className="w-full outline-none text-[14px] text-gray-700 placeholder:text-gray-400"
                />
              </div>
            </div>

            {/* Email */}
            <div className="mb-7">
              <label className="block text-[14px] font-bold mb-3">
                Email<span className="text-red-500">*</span>
              </label>

              <div className="h-[48px] border border-gray-300 rounded-lg flex items-center px-4 gap-3">
                <EmailIcon />

                <input
                  type="email"
                  value={email}
                  onChange={handleEmailChange}
                  placeholder="Enter your email"
                  required
                  className="w-full outline-none text-[14px] text-gray-700 placeholder:text-gray-400"
                />
              </div>

              {emailError !== "" && (
                <p className="mt-2 text-[12px] text-red-500">{emailError}</p>
              )}
            </div>

            {/* Password */}
            <div className="mb-2">
              <label className="block text-[14px] font-bold mb-3">
                Password<span className="text-red-500">*</span>
              </label>

              <div className="h-[48px] border border-gray-300 rounded-lg flex items-center px-4 gap-3">
                <LockIcon />

                <input
                  type="password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  placeholder="Create a password"
                  required
                  minLength={8}
                  className="w-full outline-none text-[14px] text-gray-700 placeholder:text-gray-400"
                />

              
              </div>

              <div className="mt-2 flex items-center gap-2 text-[12px] text-gray-500">
                <ShieldIcon />
                <span>At least 8 characters</span>
              </div>
            </div>

            <button
              type="submit"
              className="mt-7 w-full h-[52px] bg-[#6c5cff] text-white rounded-lg text-[14px] font-semibold hover:bg-[#5b4bea]"
            >
              Create Account
            </button>

            <p className="mt-6 text-center text-[13px] leading-6 text-gray-500">
              By creating an account, you agree to our{" "}
              <Link
                href="/terms-and-conditions"
                className="text-[#6c5cff] font-semibold"
              >
                Terms and Conditions
              </Link>{" "}
              and{" "}
              <Link
                href="/privacy-policy"
                className="text-[#6c5cff] font-semibold"
              >
                Privacy Policy.
              </Link>
            </p>
          </form>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-white px-10 md:px-12 py-16 grid grid-cols-1 md:grid-cols-4 gap-12">
        <div>
          <h2 className="text-[34px] font-bold">ShapeRush</h2>

          <p className="mt-5 text-[14px] leading-6 text-gray-500">
            Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do
            dolor sit tincidunt ut labore et dolore magna aliqua. Dolor sit
            amet, consectetur adipiscing elit.
          </p>

          <p className="mt-5 text-gray-500">©2026 by ShapeRush</p>
        </div>

        <div>
          <p className="text-[#6c5cff] text-[14px] mb-5">Address</p>

          <div className="space-y-3 text-[15px]">
            <p>641 Clementi Road,</p>
            <p>Singapore 556431</p>
          </div>
        </div>

        <div>
          <p className="text-[#6c5cff] text-[14px] mb-5">Legal</p>

          <div className="space-y-3 text-[15px]">
            <Link href="/privacy-policy" className="block">
              Privacy Policy
            </Link>

            <Link href="/terms-and-conditions" className="block">
              Terms and Conditions
            </Link>
          </div>
        </div>

        <div>
          <p className="text-[#6c5cff] text-[14px] mb-5">Contact Us</p>

          <div className="space-y-3 text-[15px]">
            <p>shaperush@gmail.com</p>
          </div>
        </div>
      </footer>
    </main>
  );
}

function UserIcon() {
  return (
    <svg
      width="19"
      height="19"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#9ca3af"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M20 21a8 8 0 0 0-16 0" />
      <circle cx="12" cy="7" r="4" />
    </svg>
  );
}

function EmailIcon() {
  return (
    <svg
      width="19"
      height="19"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#9ca3af"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <path d="m3 7 9 6 9-6" />
    </svg>
  );
}

function LockIcon() {
  return (
    <svg
      width="19"
      height="19"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#9ca3af"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="5" y="11" width="14" height="10" rx="2" />
      <path d="M8 11V7a4 4 0 0 1 8 0v4" />
    </svg>
  );
}



function FitnessIcon() {
  return (
    <svg
      width="19"
      height="19"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M6.5 6.5h11" />
      <path d="M6.5 17.5h11" />
      <path d="M3 9.5h2.5v5H3z" />
      <path d="M18.5 9.5H21v5h-2.5z" />
      <path d="M5.5 12h13" />
    </svg>
  );
}

function ShieldIcon() {
  return (
    <svg
      width="13"
      height="13"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#9ca3af"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z" />
      <path d="m9 12 2 2 4-4" />
    </svg>
  );
}