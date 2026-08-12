import Navbar from "@/app/components/Navbar";
import Footer from "@/app/components/Footer";

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

      <Footer />
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