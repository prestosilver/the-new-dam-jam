export default {
  output: {
    filename: "index.js",
    library: {
      type: "umd",
    },
    globalObject: "this",
  },
  module: {
    rules: [
      {
        test: /\.ts$/,
        use: "ts-loader",
        exclude: "/node-modules/",
      },
    ],
  },
  resolve: {
    extensions: [".ts"],
  },
};
