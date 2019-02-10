<template>
  <div id="app">
    <WaffenViz :auswahl="false" />
  </div>
</template>

<script>
import WaffenViz from "./components/WaffenViz.vue";

export default {
  name: "app",
  components: {
    WaffenViz
  }
};
</script>

<style lang="scss">
#app {
  font-family: "Avenir", Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
}
</style>
