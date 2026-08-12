import Link from "next/link";

export default function Footer() {
  return (
    <footer className="bg-white px-10 md:px-12 py-16 grid grid-cols-1 md:grid-cols-4 gap-12">
      <div>
        <h2 className="text-[34px] font-bold">ShapeRush</h2>

        <p className="mt-5 text-[14px] leading-6 text-gray-500">
          ShapeRush brings structured workout plans, nutrition tracking and
          professional guidance together in one app, so you can train with a
          plan instead of guessing.
        </p>

        <p className="mt-5 text-gray-500">©2026 by ShapeRush</p>
      </div>

      <FooterColumn
        title="Address"
        lines={["641 Clementi Road,", "Singapore 556431"]}
      />

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

      <FooterColumn title="Contact Us" lines={["shaperush@gmail.com"]} />
    </footer>
  );
}

function FooterColumn({ title, lines }) {
  return (
    <div>
      <p className="text-[#6c5cff] text-[14px] mb-5">{title}</p>

      <div className="space-y-3 text-[15px]">
        {lines.map((line) => (
          <p key={line}>{line}</p>
        ))}
      </div>
    </div>
  );
}
