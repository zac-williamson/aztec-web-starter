import { defineConfig } from 'vite';
import { PolyfillOptions, nodePolyfills } from 'vite-plugin-node-polyfills';

const nodePolyfillsFix = (options?: PolyfillOptions | undefined): Plugin => {
  return {
    ...nodePolyfills(options),
    /* @ts-ignore */
    resolveId(source: string) {
      const m = /^vite-plugin-node-polyfills\/shims\/(buffer|global|process)$/.exec(source);
      if (m) {
        return `./node_modules/vite-plugin-node-polyfills/shims/${m[1]}/dist/index.cjs`;
      }
    },
  };
};

export default defineConfig(({ mode }) => {
  return {
    optimizeDeps: {
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
      nodePolyfillsFix({ include: ['buffer', 'path'] }),
    ],
  };
});
