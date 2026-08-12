import Navbar from "@/app/components/Navbar";
import Footer from "@/app/components/Footer";

export default function ApplicationSubmittedPage() {
  return (
    <main className="min-h-screen bg-[#f8f8ff] text-black">
      <Navbar />

      {/* Main Content */}
      <section className="min-h-[520px] flex items-center justify-center px-10 md:px-12 py-20">
        <div className="w-full max-w-[960px] grid grid-cols-1 md:grid-cols-2 gap-16 items-center">
          {/* Left Text */}
          <div>
            <h1 className="text-[30px] md:text-[32px] font-bold">
              Thank you for your application!
            </h1>

            <p className="mt-6 text-[17px] leading-7 text-gray-500 max-w-[430px]">
              Install the app now. We&apos;ll notify you via email
              <br />
              when your application is approved.
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
                href="/ShapeRush.apk"
                download
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