import Vue from "vue";
import App from "./App.vue";

import * as format from "d3-format";
const locale = format.formatDefaultLocale({
  decimal: ",",
  thousands: ".",
  grouping: [3],
  currency: ["", "\u00a0€"]
});
Vue.prototype.$fmt = locale.format;

Vue.config.productionTip = false;

new Vue({
  render: h => h(App)
}).$mount("#app");
