import Navbar from "@/app/components/Navbar";
import Footer from "@/app/components/Footer";

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

      <Footer />
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