import Link from "next/link";
import Navbar from "@/app/components/Navbar";

export default function TermsAndConditionsPage() {
  return (
    <main className="min-h-screen bg-[#f8f8ff] text-black">
      <Navbar />

      {/* Content */}
      <section className="px-10 py-20">
        <div className="max-w-[760px] mx-auto">
          <h1 className="text-center text-[28px] font-bold mb-12">
            Terms and Conditions
          </h1>

          <ContentBlock
            title="Acceptance of Terms"
            text='By downloading, installing, or using the GoodGrit application ("App"), you ("User") agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, do not use the App.'
          />

          <ContentBlock
            title="Eligibility"
            text="To use the App, you must be at least 16 years old and capable of entering into a legally binding agreement. By using the App, you represent and warrant that you meet these requirements."
          />

          <SectionTitle title="Health and Safety Disclaimer" />

          <ContentBlock
            title="General Health"
            text="Users should consult with a healthcare professional before starting any exercise program, especially if they have any medical conditions, are pregnant, or have not exercised in a long time. GoodGrit is not responsible for any health issues that may arise from using the App."
          />

          <ContentBlock
            title="Physical Limitations"
            text="The App’s workouts are designed for individuals of varying fitness levels. Users should respect their physical limitations and avoid activities that cause pain or discomfort. GoodGrit is not liable for any injuries or health issues resulting from the use of the App."
          />

          <SectionTitle title="Health and Safety Disclaimer" />

          <ContentBlock
            title="General Health"
            text="Users should consult with a healthcare professional before starting any exercise program, especially if they have any medical conditions, are pregnant, or have not exercised in a long time. GoodGrit is not responsible for any health issues that may arise from using the App."
          />

          <ContentBlock
            title="Physical Limitations"
            text="The App’s workouts are designed for individuals of varying fitness levels. Users should respect their physical limitations and avoid activities that cause pain or discomfort. GoodGrit is not liable for any injuries or health issues resulting from the use of the App."
          />
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

function SectionTitle({ title }) {
  return (
    <h2 className="text-[21px] font-bold mt-10 mb-5">
      {title}
    </h2>
  );
}

function ContentBlock({ title, text }) {
  return (
    <div className="mb-8">
      <h3 className="text-[18px] font-bold mb-4">
        {title}
      </h3>

      <p className="text-[15px] leading-5 text-gray-600">
        {text}
      </p>
    </div>
  );
}