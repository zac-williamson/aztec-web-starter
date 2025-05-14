import { defineConfig } from 'vite';
import { nodePolyfills } from 'vite-plugin-node-polyfills';

export default defineConfig(({ mode }) => {
  return {
    optimizeDeps: {
      // We require wasm files exported by these packages to be part of the bundle
      // "exlucding" them does the trick
      exclude: ['@aztec/noir-noirc_abi', '@aztec/noir-acvm_js']
    },
    rollupOptions: {
      input: 'index.html',
      output: {
        dir: 'dist',
        format: 'esm'
      }
    },
    server: {
      // Headers needed for bb WASM to work in multithreaded mode
      headers: {
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
      },
    },
    plugins: [
      nodePolyfills({ include: ['buffer', 'path'] }),
    ],
  };
});
