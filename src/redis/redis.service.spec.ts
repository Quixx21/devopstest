import { Test, TestingModule } from '@nestjs/testing';
import { RedisService } from './redis.service';
import { ConfigService } from '@nestjs/config';

describe('RedisService', () => {
	let service: RedisService;

	beforeEach(async () => {
		const module: TestingModule = await Test.createTestingModule({
			providers: [
				RedisService,
				{
					provide: ConfigService,
					useValue: {
						get: jest.fn((key: string) => {
							if (key === 'REDIS_HOST') return 'localhost';
							if (key === 'REDIS_PORT') return 6379;
							if (key === 'REDIS_PASSWORD') return 'password';
							return null;
						}),
					},
				},
			],
		}).compile();

		service = module.get<RedisService>(RedisService);
	});

	it('should be defined', () => {
		expect(service).toBeDefined();
	});
});
