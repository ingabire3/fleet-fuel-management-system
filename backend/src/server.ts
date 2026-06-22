import { createApp } from "./app";
import { env } from "./config/env";
import { logger } from "./config/logger";
import { startScheduler } from "./jobs/scheduler";

const app = createApp();

app.listen(env.PORT, () => {
  logger.info(`Server listening on port ${env.PORT} (${env.NODE_ENV})`);
  startScheduler();
});
