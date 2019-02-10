module.exports = {
  //...
  devServer: {
    host: "localhost"
  },
  css: {
    extract: false
  },
  filenameHashing: false,
  baseUrl: "./",

  chainWebpack: config => {
    // GraphQL Loader
    config.module
      .rule("csv")
      .test(/\.csv/)
      .use("dsv-loader")
      .loader("dsv-loader")
      .end();
    config.module
      .rule("archieml")
      .test(/\.archieml/)
      .use("@newsdev/archieml-loader")
      .loader("@newsdev/archieml-loader")
      .end();
  },

  pages: {
    index: {
      entry: "src/main.js",
      template: "public/index.html"
    },
    index_justmap: {
      entry: "src/main_justmap.js",
      template: "public/index_justmap.html"
    },
    index_scrolly: {
      entry: "src/main_scrolly.js",
      template: "public/index_scrolly.html"
    }
  }
};
