"use client";

import Link from "next/link";
import { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import Navbar from "@/app/components/Navbar";

function CheckEmailContent() {
  const searchParams = useSearchParams();
  const email = searchParams.get("email") || "your email";

  return (
    <p className="mt-5 text-[16px] leading-7 text-black">
      To keep a trusted and safe community, we&apos;ve sent an email to{" "}
      <span className="font-bold">{email}</span> for verification,
      you&apos;ll only do this once.
    </p>
  );
}

export default function CheckEmailPage() {
  return (
    <main className="min-h-screen bg-[#f8f8ff] text-black">
      <Navbar />

      {/* Check Email Content */}
      <section className="min-h-[640px] flex items-center justify-center px-6 py-16">
        <div className="w-full max-w-[640px] bg-white rounded-[28px] shadow-sm px-10 md:px-12 py-12">
          <h1 className="text-[22px] font-bold">Check your Email</h1>

          <Suspense fallback={<p className="mt-5 text-[16px] leading-7 text-black">Loading...</p>}>
            <CheckEmailContent />
          </Suspense>

          <div className="mt-12 flex justify-center">
            <MailIllustration />
          </div>
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

function MailIllustration() {
  return (
    <svg
      width="180"
      height="140"
      viewBox="0 0 180 140"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <circle cx="48" cy="82" r="9" fill="#F9D85E" stroke="#222" />
      <circle cx="135" cy="38" r="7" fill="#F9D85E" stroke="#222" />

      <path
        d="M68 54C67 39 80 28 99 27C118 26 132 38 130 53C128 67 113 76 94 76C76 76 69 66 68 54Z"
        fill="#C7C1FF"
        stroke="#222"
      />

      <circle cx="93" cy="53" r="20" fill="white" stroke="#222" />

      <path
        d="M93 67L125 67C137 67 142 72 142 84L142 105C142 116 136 121 124 121L82 117C73 116 69 111 69 102L69 77L93 67Z"
        fill="#6257F6"
        stroke="#222"
      />

      <path d="M71 78L104 102L141 76" stroke="#222" />
      <path d="M88 118L107 100" stroke="#222" />
      <path d="M124 119L107 100" stroke="#222" />

      <path
        d="M112 20C112 11 115 7 122 7C127 7 129 11 128 17L124 34C123 38 120 40 116 39C112 38 110 35 111 31L112 20Z"
        fill="#444"
        stroke="#222"
      />

      <circle cx="116" cy="48" r="6" fill="#444" stroke="#222" />
    </svg>
  );
}