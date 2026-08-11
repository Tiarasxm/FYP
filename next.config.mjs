/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "tltbtwctxaxsevcxwwco.supabase.co",
      },
    ],
  },
};

export default nextConfig;
