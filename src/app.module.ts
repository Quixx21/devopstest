import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrometheusModule } from '@willsoto/nestjs-prometheus';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { RedisService } from './redis/redis.service';

@Module({
	imports: [
		ConfigModule.forRoot({
			isGlobal: true,
		}),
		// Prometheus metrics
		PrometheusModule.register({
			path: '/metrics', //endpoint
			defaultMetrics: {
				enabled: true,
			},
		}),
	],
	controllers: [AppController],
	providers: [AppService, RedisService],
})
export class AppModule {}
