/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  eslint: { ignoreDuringBuilds: true }, // pas d'ESLint installé dans le prototype
};
export default nextConfig;
