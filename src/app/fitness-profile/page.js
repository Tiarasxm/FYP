"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

export default function FitnessProfilePage() {
  const router = useRouter();

  const [displayName, setDisplayName] = useState("");
  const [bio, setBio] = useState("");
  const [experience, setExperience] = useState(0);
  const [specializations, setSpecializations] = useState("");
  const [certificate, setCertificate] = useState(null);
  const [profileErrorMessage, setProfileErrorMessage] = useState("");

  async function completeProfile() {
    const { data: userData, error: userError } = await supabase.auth.getUser();

    if (userError || !userData?.user) {
      router.push("/login");
      return;
    }

    const user = userData.user;

    const role =
      localStorage.getItem("googleRegisterRole") ||
      user.user_metadata?.role ||
      "Fitness professional";

    const fullName =
      user.user_metadata?.full_name ||
      user.user_metadata?.name ||
      user.email?.split("@")[0] ||
      "User";

    setDisplayName(fullName);

    const { error: profileError } = await supabase.from("profiles").upsert(
      {
        id: user.id,
        full_name: fullName,
        email: user.email,
        user_type: role,
        status: "active",
      },
      {
        onConflict: "id",
      }
    );

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

    localStorage.removeItem("googleRegisterRole");
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- setState calls happen after network awaits, not synchronously
    completeProfile();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- intentionally run once on mount
  }, []);

  async function handleSubmit(event) {
    event.preventDefault();

    if (!displayName.trim()) {
      alert("Please enter your display name.");
      return;
    }

    if (!bio.trim()) {
      alert("Please enter your professional bio.");
      return;
    }

    if (!specializations.trim()) {
      alert("Please enter your specializations.");
      return;
    }

    if (!certificate) {
      alert("Please upload your certification.");
      return;
    }

    const { data: userData, error: userError } = await supabase.auth.getUser();

    if (userError || !userData?.user) {
      alert("Please login again before submitting your application.");
      router.push("/register");
      return;
    }

    const user = userData.user;

    const safeFileName = certificate.name.replace(/[^a-zA-Z0-9._-]/g, "_");
    const filePath = `${user.id}/${Date.now()}-${safeFileName}`;

    const { error: uploadError } = await supabase.storage
      .from("certifications")
      .upload(filePath, certificate, {
        upsert: true,
      });

    if (uploadError) {
      alert(uploadError.message);
      return;
    }


    const { error: profileError } = await supabase
      .from("profiles")
      .update({
        full_name: displayName,
        user_type: "Fitness professional",
        status: "pending",
      })
      .eq("id", user.id);

    if (profileError) {
      alert(profileError.message);
      return;
    }

    const { error: proError } = await supabase
      .from("fitness_professional")
      .upsert(
        {
          profile_id: user.id,
          display_name: displayName,
          bio: bio,
          experience: Number(experience),
          specializations: specializations,
          certificate_name: certificate.name,
          certificate_path: filePath,
          approved: false,
          submitted_at: new Date().toISOString(),
        },
        {
          onConflict: "profile_id",
        }
      );

    if (proError) {
      alert(proError.message);
      return;
    }

    await supabase.auth.updateUser({
      data: {
        full_name: displayName,
        role: "Fitness professional",
      },
    });

    router.push("/application-submitted");
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

      {profileErrorMessage && (
        <div className="bg-red-50 border-b border-red-200 text-red-700 text-[14px] text-center px-6 py-3">
          {profileErrorMessage}
        </div>
      )}

      {/* Form Section */}
      <section className="min-h-[760px] flex items-center justify-center px-6 py-16">
        <div
          className="bg-white rounded-[22px] shadow-sm px-8 py-9"
          style={{ width: "440px", maxWidth: "calc(100vw - 48px)" }}
        >
          <h1 className="text-[26px] font-bold">Complete your profile</h1>

          <p className="mt-4 text-[15px] font-semibold text-gray-500">
            Start your fitness journey today.
          </p>

          <form onSubmit={handleSubmit} className="mt-8">
            {/* Display Name */}
            <div className="mb-6">
              <label className="block text-[14px] font-bold mb-3">
                Display Name<span className="text-red-500">*</span>
              </label>

              <input
                type="text"
                value={displayName}
                onChange={(event) => setDisplayName(event.target.value)}
                placeholder="Enter your full name"
                className="w-full h-[48px] border border-gray-300 rounded-lg px-4 outline-none text-[14px] text-gray-700 placeholder:text-gray-400"
              />
            </div>

            {/* Professional Bio */}
            <div className="mb-6">
              <label className="block text-[14px] font-bold mb-3">
                Professional Bio<span className="text-red-500">*</span>
              </label>

              <textarea
                value={bio}
                onChange={(event) => setBio(event.target.value)}
                placeholder="Enter your bio"
                className="w-full h-[92px] border border-gray-300 rounded-lg px-4 py-3 outline-none resize-none text-[14px] text-gray-700 placeholder:text-gray-400"
              />
            </div>

            {/* Years Experience */}
            <div className="mb-6">
              <label className="block text-[14px] font-bold mb-3">
                Years Experience<span className="text-red-500">*</span>
              </label>

              <input
                type="number"
                min="0"
                value={experience}
                onChange={(event) => setExperience(event.target.value)}
                className="w-full h-[48px] border border-gray-300 rounded-lg px-4 outline-none text-[14px] text-gray-700"
              />
            </div>

            {/* Specializations */}
            <div className="mb-6">
              <label className="block text-[14px] font-bold mb-3">
                Specializations<span className="text-red-500">*</span>
              </label>

              <input
                type="text"
                value={specializations}
                onChange={(event) => setSpecializations(event.target.value)}
                placeholder="e.g HIIT, Yoga, Nutrition, Strength Training..."
                className="w-full h-[48px] border border-gray-300 rounded-lg px-4 outline-none text-[14px] text-gray-700 placeholder:text-gray-400"
              />
            </div>

            {/* Upload Certifications */}
            <div className="mb-6">
              <label className="block text-[14px] font-bold mb-3">
                Upload certifications<span className="text-red-500">*</span>
              </label>

              <label className="h-[140px] border border-dashed border-gray-300 rounded-lg flex flex-col items-center justify-center cursor-pointer hover:bg-gray-50">
                <FileIcon />

                <p className="mt-4 text-[14px] text-black text-center">
                  Choose a file or drag and drop it here
                </p>

                <p className="mt-2 text-[13px] text-gray-500">
                  Maximum 500 MB file size
                </p>

                {certificate && (
                  <p className="mt-2 text-[12px] text-[#6c5cff] font-semibold text-center">
                    {certificate.name}
                  </p>
                )}

                <input
                  type="file"
                  className="hidden"
                  onChange={(event) => setCertificate(event.target.files[0])}
                />
              </label>
            </div>

            <button
              type="submit"
              className="w-full h-[52px] bg-[#6c5cff] text-white rounded-lg text-[14px] font-semibold hover:bg-[#5b4bea]"
            >
              Submit Application
            </button>
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

function FileIcon() {
  return (
    <svg
      width="42"
      height="42"
      viewBox="0 0 24 24"
      fill="none"
      stroke="#9ca3af"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <path d="M14 2v6h6" />
    </svg>
  );
}