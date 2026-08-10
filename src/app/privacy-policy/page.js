import Link from "next/link";
import Navbar from "@/app/components/Navbar";

export default function PrivacyPolicyPage() {
  return (
    <main className="min-h-screen bg-[#f8f8ff] text-black">
      <Navbar />

      {/* Content */}
      <section className="px-10 py-20">
        <div className="max-w-[760px] mx-auto">
          <h1 className="text-center text-[28px] font-bold mb-12">
            Privacy Policy
          </h1>

          <PolicyBlock
            title="A legal disclaimer"
            text="This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You. We use Your Personal data to provide and improve the Service. By using the Service, You agree to the collection and use of information in accordance with this Privacy Policy."
          />

          <PolicySectionTitle title="Interpretation and Definition" />

          <PolicyBlock
            title="Interpretation"
            text="This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You. We use Your Personal data to provide and improve the Service. By using the Service, You agree to the collection and use of information in accordance with this Privacy Policy."
          />

          <PolicyBlock
            title="Definition"
            text="This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You. We use Your Personal data to provide and improve the Service. By using the Service, You agree to the collection and use of information in accordance with this Privacy Policy."
          />

          <PolicySectionTitle title="Interpretation and Definition" />

          <PolicyBlock
            title="Interpretation"
            text="This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You. We use Your Personal data to provide and improve the Service. By using the Service, You agree to the collection and use of information in accordance with this Privacy Policy."
          />

          <PolicyBlock
            title="Definition"
            text="This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You. We use Your Personal data to provide and improve the Service. By using the Service, You agree to the collection and use of information in accordance with this Privacy Policy."
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

function PolicySectionTitle({ title }) {
  return (
    <h2 className="text-[21px] font-bold mt-10 mb-5">
      {title}
    </h2>
  );
}

function PolicyBlock({ title, text }) {
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