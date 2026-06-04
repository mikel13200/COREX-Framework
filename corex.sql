-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               12.2.2-MariaDB - MariaDB Server
-- Server OS:                    Win64
-- HeidiSQL Version:             12.14.0.7165
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Dumping database structure for corex
CREATE DATABASE IF NOT EXISTS `corex` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */;
USE `corex`;

-- Dumping structure for table corex.inventories
CREATE TABLE IF NOT EXISTS `inventories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(60) NOT NULL,
  `inventory_type` varchar(50) NOT NULL DEFAULT 'player',
  `inventory_id` varchar(60) NOT NULL,
  `items` longtext NOT NULL,
  `hotbar` longtext NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_inventory` (`identifier`,`inventory_type`,`inventory_id`),
  KEY `idx_inventory_lookup` (`identifier`,`inventory_type`),
  KEY `idx_inventory_id` (`inventory_id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table corex.inventories: ~0 rows (approximately)
INSERT INTO `inventories` (`id`, `identifier`, `inventory_type`, `inventory_id`, `items`, `hotbar`, `created_at`, `updated_at`) VALUES
	(15, 'license:2b9d3b1e8412898d356e6debebd6d232d73409ea', 'player', 'license:2b9d3b1e8412898d356e6debebd6d232d73409ea', '[{"name":"weapon_carbinerifle","count":1,"metadata":[],"slot":"516011-1","x":1,"y":1},{"name":"pistol_ammo","count":844,"metadata":[],"slot":"645117-4","x":4,"y":1},{"name":"weapon_pistol","count":1,"metadata":[],"slot":"653840-5","x":5,"y":1},{"name":"WEAPON_PISTOL_MK2","count":1,"metadata":{"ammo":194},"slot":"835024-6","x":7,"y":1}]', '{}', '2026-04-25 11:37:43', '2026-04-27 00:05:02');

-- Dumping structure for table corex.players
CREATE TABLE IF NOT EXISTS `players` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(60) NOT NULL,
  `name` varchar(50) NOT NULL DEFAULT 'Unknown',
  `money` longtext NOT NULL,
  `metadata` longtext NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `identifier` (`identifier`),
  KEY `idx_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=236 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table corex.players: ~1 rows (approximately)
INSERT INTO `players` (`id`, `identifier`, `name`, `money`, `metadata`, `created_at`, `updated_at`) VALUES
	(92, 'license:2b9d3b1e8412898d356e6debebd6d232d73409ea', 'XX BNK GOD', '{"bank":500,"cash":100}', '{"infection":54.5,"lastPosition":{"x":1959.5472412109376,"heading":246.61416625976569,"z":122.189697265625,"y":2072.597900390625},"stress":0,"sick":0,"cold":0,"skin":{"headBlend":{"shapeSecond":0,"skinMix":0.0,"shapeMix":0.0,"thirdMix":0.0,"shapeFirst":45,"shapeThird":0,"skinSecond":0,"skinFirst":0,"skinThird":0},"hair":{"texture":0,"style":0,"highlight":0,"color":0},"headOverlays":{"bodyBlemishes":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"moleAndFreckles":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"lipstick":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"sunDamage":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"eyebrows":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"makeUp":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"complexion":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"beard":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"blemishes":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"ageing":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"chestHair":{"opacity":0.0,"style":0,"color":0,"secondColor":0},"blush":{"opacity":0.0,"style":0,"color":0,"secondColor":0}},"components":{"4":{"texture":0,"drawable":0},"3":{"texture":0,"drawable":0},"6":{"texture":0,"drawable":0},"5":{"texture":0,"drawable":0},"0":{"texture":0,"drawable":0},"10":{"texture":0,"drawable":0},"2":{"texture":0,"drawable":0},"1":{"texture":0,"drawable":0},"8":{"texture":0,"drawable":0},"7":{"texture":0,"drawable":0},"11":{"texture":0,"drawable":0},"9":{"texture":0,"drawable":0}},"eyeColor":0,"model":"mp_m_freemode_01","faceFeatures":{"chinBoneLowering":0.0,"noseWidth":0.0,"lipsThickness":0.0,"chinBoneSize":0.0,"cheeksWidth":0.0,"jawBoneBackSize":0.0,"noseBoneTwist":0.0,"eyesOpening":0.0,"chinHole":0.0,"jawBoneWidth":0.0,"chinBoneLenght":0.0,"cheeksBoneWidth":0.0,"nosePeakLowering":0.0,"neckThickness":0.0,"eyeBrownForward":0.0,"nosePeakSize":0.0,"cheeksBoneHigh":0.0,"noseBoneHigh":0.0,"nosePeakHigh":0.0,"eyeBrownHigh":0.0},"props":{"4":{"texture":-1,"drawable":-1},"3":{"texture":-1,"drawable":-1},"6":{"texture":-1,"drawable":-1},"5":{"texture":-1,"drawable":-1},"0":{"texture":-1,"drawable":-1},"7":{"texture":-1,"drawable":-1},"2":{"texture":-1,"drawable":-1},"1":{"texture":-1,"drawable":-1}}},"thirst":27.39999999999945,"hunger":38.04999999999999,"lifecycleState":"loading","poison":0,"bleeding":0,"poisoning":0}', '2026-04-25 11:37:41', '2026-04-27 00:05:02');

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
