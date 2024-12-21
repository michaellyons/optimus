/// <reference path="./.sst/platform/config.d.ts" />

export default $config({
  app(input) {
    return {
      name: "eliza-starter",
      removal: input?.stage === "production" ? "retain" : "remove",
      home: "aws",
    };
  },
  async run() {

    const secrets = {
      supabaseUrl: new sst.Secret("SUPABASE_URL", "some-secret-value-1"),
      supabaseAnonKey: new sst.Secret("SUPABASE_ANON_KEY", "some-secret-value-2"),
      openAIApiKey: new sst.Secret("OPENAI_API_KEY", "some-secret-value-2"),
      discordAppId: new sst.Secret("DISCORD_APPLICATION_ID", "some-secret-value-2"),
      discordApiToken: new sst.Secret("DISCORD_API_TOKEN", "some-secret-value-2"),
      telegramBotToken: new sst.Secret("TELEGRAM_BOT_TOKEN", "some-secret-value-2"),
    };
    const allSecrets = Object.values(secrets);

    const vpc = new sst.aws.Vpc("MyVpc");
    const cluster = new sst.aws.Cluster("MyCluster", { vpc });
    cluster.addService("MyService", {
      loadBalancer: {
        ports: [{ listen: "80/http", forward: "3000/http" }],
      },
      link: [...allSecrets],
      environment: {
        SUPABASE_URL: secrets.supabaseUrl.value,
        SUPABASE_ANON_KEY: secrets.supabaseAnonKey.value,
        OPENAI_API_KEY: secrets.openAIApiKey.value,
        DISCORD_APPLICATION_ID: secrets.discordAppId.value,
        DISCORD_API_TOKEN: secrets.discordApiToken.value,
        // TELEGRAM_BOT_TOKEN: secrets.telegramBotToken.value
      },
      cpu: "1 vCPU",
      memory: "4 GB",
      dev: {
        command: "bun dev",
      },
    });
  }
});
