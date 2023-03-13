/**
* Name: validationmodeletranshumance
* Based on the internal empty template. 
* Author: HP
* Tags: 
* Le réseau social du transhumant est créer autour des chemins des colliers GPS pris en entrée;
* 
*/
model validationt2

/* Insert your model definition here */
global {
	file shape_file_forage <- file("../includes/forage_roi_collier_gps_cassecs.shp");
	file shape_file_appetence <- file("../includes/morphopedo_roi_collier_gps_cassecs.shp");
	file shape_file_hydro_line <- file("../includes/hydro_line_collier_gps_cassecs.shp");
	file shape_file_fusion <- file("../includes/fusion_t2.shp");
	file shape_file_infrastructure_pasto <- file("../includes/parc_vaccination_collier_gps_cassecs.shp");
	file map_init;
	file map_init3 <- image_file("../includes/ze_redim3.0.png");
	file map_init6 <- image_file("../includes/ze_redim6.0.png");
	file map_init9 <- image_file("../includes/ze_redim9.0.png");
	file map_init12 <- image_file("../includes/ze_redim12.0.png");
	file map_init15 <- image_file("../includes/ze_redim15.0.png");
	file map_init18 <- image_file("../includes/ze_redim18.0.png");
	file map_init21 <- image_file("../includes/ze_redim21.0.png");
	file map_init24 <- image_file("../includes/ze_redim24.0.png");
	file map_init27 <- image_file("../includes/ze_redim27.0.png");
	file map_init30 <- image_file("../includes/ze_redim30.0.png");
	file map_init33 <- image_file("../includes/ze_redim33.0.png");
	file map_init36 <- image_file("../includes/ze_redim36.0.png");
	file shape_file_marche <- file("../includes/marche_betail_collier_gps_cassecs.shp");
	geometry shape <- envelope(shape_file_appetence);

	//---------------------------------------les paramètres----------------------------------------
	date starting_date <- date([2020, 10, 15, 7, 0]);
	float step <- 1 #days;
	int nb_trp <- 9 min: 9 max: 9 parameter: 'Nb_trp';
	int nb_bovin <- 0;
	int np_pti_rum <- 0;
	int cpt_trp_retour;
	float pct <- 0.0;
	float pcnt <- 0.0;
	float std_pct <- 0.0;
	float std_pcnt <- 0.0;
	int temp <- 10;
	bool is_batch <- false;
	bool is_batch_impact_tout_parametre <- false;
	bool is_batch_espace_collier <- false;
	bool is_batch_impact_espace <- false;
	bool is_batch_vitesse <- false;
	bool is_batch_veg <- false;
	bool is_batch_ws <- false;
	bool is_batch_veg_ws <- false;
	float lambda1 <- 0.25 min: 0.25 max: 0.75;
	float lambda2 <- 0.5 min: 0.25 max: 0.75;
	int nb_repliq <- 35 min: 5 parameter: 'nb_replication' category: 'espace';

	//---------------------------------------------------------------------------
	float acc_bovin_moy <- 2.5 min: -10.0 max: 10.0 parameter: 'Bovin' category: "Accroissement (%) Ruminants";
	float acc_ovin_moy <- 3.5 min: -10.0 max: 25.0 parameter: 'Ovin' category: "Accroissement (%) Ruminants";
	float acc_caprin_moy <- 4.5 min: -10.0 max: 35.0 parameter: 'Caprin' category: "Accroissement (%) Ruminants";
	float com_bovin_moy <- 4.5 min: 1.0 parameter: 'Bovin' category: "Consommation journalière biomasse";
	float com_ovin_moy <- 1.5 min: 1.0 parameter: 'Ovin' category: "Consommation journalière biomasse";
	float com_caprin_moy <- 1.5 min: 1.0 parameter: 'Caprin' category: "Consommation journalière biomasse";
	float s_cons_jour <- 0.0;
	//veterinaire
	int jour_veto <- 4 min: 0 parameter: 'jour(s)' category: 'Veterinaire';

	//Réseau social
	bool rs_exist <- true parameter: 'Social' category: 'Reseau_social';
	float d_res_soc <- 100 #km min: 15 #km max: 105 #km parameter: 'Dist_soc' category: 'Reseau_social';
	int jour_res_soc <- 4 min: 0 parameter: 'Nb jour' category: 'Reseau_social';
	float p_res_social <- 0.43 min: 0.0 parameter: 'accueil_ZA' category: 'Reseau_social';
	int elmt_res_social <- 5 min: 1 parameter: 'nb_rs_path' category: 'Reseau_social';

	//---------------------------------- espace et vegetation ----------------
	float largeur_cellule <- 18 #km ;//min: 3 #km step: 3 #km max: 36 #km parameter: "dimension_cellule" category: "espace";
	float hauteur_cellule <- largeur_cellule;
	float impt_trp_veg <- 0.0;
	rgb impt_trp_veg_color <- #green;
	rgb veg_color <- #green;
	float evolution_veg <- sum(espace collect (each.r_init));
	float sous_seuil_veg <- 0.0;
	float q_seuil_r <- 0.33 min: 0.008 max: 0.9 parameter: "Sueil_biomasse" category: "Impact troupeau-végétation";
	//le seuil de végétation, ce sueil(25%) est tiré de Dia et Duponnois:désertification
	float qt_pluie <- 150.0 min: 105.0 max: 700.0 parameter: 'Pluviométrie';
	//rnd(100.0, 550.0) min: 50.0 max: 550.0 parameter: "Pluie(mm)" category: "Climat";
	string plvt;
	//interaction trp_veg
	float d_rech <- 6 #km min: 2 #km parameter: "dist-recherche-bio" category: "Impact troupeau-végétation";
	bool init_grille <- false;
	//------------------------------- paramètre d'optimisation ---------------
	float cout_eau <- 3250.0 parameter: "Eau" category: "Mecanisme optimisation"; // Ancey 2008
	float cou_soin_moy <- 89000.0 parameter: 'Soin' category: "Mecanisme optimisation";
	float cou_vente_moy <- 50000.0 parameter: 'vente' category: "Mecanisme optimisation";
	int nb_j_vente <- 3 min: 3 parameter: ' jour vente' category: "Mecanisme optimisation";
	float cou_vol_moy <- 10000.0 parameter: 'Vol' category: "Mecanisme optimisation";
	float vitesse_aller <- 12.0 min: 12.0 max: 22.0 parameter: 'Vitesse aller' category: "Mecanisme optimisation";
	float vitesse_retour <- 14.0 min: 14.0 max: 30.0 parameter: 'Vitesse retour' category: "Mecanisme optimisation";
	//----------------- le calendrier pastoral ------------------------------
	date date_mj_pluie <- date([2021, 10, 10]);
	date date_mj_biomasse <- date([2021, 10, 1]);
	date d_cetcelde <- date([2021, 5, 15]);
	date f_cetcelde <- date([2021, 6, 30]);
	date fin_sai_pluie <- date([2021, 9, 30]);
	date fin_transh_au_plus_tard <- date([2021, 7, 1]);
	//------------------------- diffusion --------
	init {
		create forage from: shape_file_forage; // with: [forage_debit::float(get("Débit_expl"))];
		create colliers from: shape_file_fusion with: [collier::string(get("layer"))];
		create infrast_pasto from: shape_file_infrastructure_pasto; // with: [type:: string(get("type"))];
		create marche_roi from: shape_file_marche;
		create vegetation from: shape_file_appetence with: [pasto::string(get("PASTORAL"))] {
			if pasto = "N" {
				color_vegetation <- #red; // rgb(165, 38, 10); //
			} else if pasto = "P1" {
				color_vegetation <- rgb(58, 137, 35); //#darkgreen; // pâturage généralement de bonne qualité
			} else if pasto = "P2" {
				color_vegetation <- rgb(1, 215, 88); //#green; // pâturage généralement de qualité moyenne
			} else if pasto = "P3" {
				color_vegetation <- rgb(34, 120, 15); //#lime; // pâturage généralement de qualité médiocre ou faible
			} else if pasto = "P4" {
				color_vegetation <- rgb(176, 242, 182); //#aqua; //  pâturage uniquement exploitable en saison sèche, inondable
			} else {
				color_vegetation <- #black;
			} }

		ask vegetation {
		// prise de couleur par la grille
			ask espace overlapping (self) {
				self.color <- myself.color_vegetation;
				self.e_pasto <- myself.pasto;
			}

		}

		create hydro_ligne from: shape_file_hydro_line;
		create troupeau number: nb_trp;
		//initialisation de plvt
		if 450.0 <= qt_pluie and qt_pluie <= 550 {
			plvt <- 'bonne';
		} else if 300.0 <= qt_pluie and qt_pluie <= 449 {
			plvt <- 'moyenne';
		} else {
			plvt <- 'sécheresse';
		}
		//------- Marquage espace utilisé 
		/*ask colliers {
			ask grille overlapping self {
				self.color <- #blue;
			}

		}*/
//--------------- image raster ------------
		//Choix du raster
		if largeur_cellule = 3 #km {
			map_init <- map_init3;
		} else if largeur_cellule = 6 #km {
			map_init <- map_init6;
		} else if largeur_cellule = 9 #km {
			map_init <- map_init9;
		} else if largeur_cellule = 12 #km {
			map_init <- map_init12;
		} else if largeur_cellule = 15 #km {
			map_init <- map_init15;
		} else if largeur_cellule = 18 #km {
			map_init <- map_init18;
		} else if largeur_cellule = 21 #km {
			map_init <- map_init21;
		} else if largeur_cellule = 24 #km {
			map_init <- map_init24;
		} else if largeur_cellule = 27 #km {
			map_init <- map_init27;
		} else if largeur_cellule = 30 #km {
			map_init <- map_init30;
		} else if largeur_cellule = 33 #km {
			map_init <- map_init33;
		} else if largeur_cellule = 36 #km {
			map_init <- map_init36;
		} else {
			write 'mauvaise dimension de cellule de grille';
			do die;
		}

		ask espace {
			if map_init = nil {
				color2 <- rgb(0, 0, 0);
			} else {
				color2 <- rgb(map_init at {grid_x, grid_y});
			}

			//-------------------- initialisation de la vegetation ---------------------------------
			if self.e_pasto = "P1" or self.e_pasto = "P2" or self.e_pasto = "P3" or self.e_pasto = "P4" {
				r_init <- qt_pluie != 0 ? (4.1 * qt_pluie - 515) * hauteur_cellule * largeur_cellule * (1 - (((color2 as list) at 0) / 255)) : 1;
				r <- r_init;
				if r_init = 0.0 { // resoud les exeption du cas ou il n'y a pas de vegetation dans un endroit à l'initialisation
					r_init <- 1.0;
					r <- 1.0;
				}

			} else {
				r_init <- 1.0;
				r <- 1.0;
			}

		} } // fin de l'init

	//----------------- debut operation de diffusion -----------
	bool diff_eau <- true;

	reflex var_dif_eau when: diff_eau {
		ask espace {
			ask forage inside self {
				myself.esp_forage <- true;
			}

			ask marche_roi inside self {
				myself.esp_infrast_marche <- true;
			}

			ask infrast_pasto inside self {
				myself.esp_infrast_veto <- true;
			}

		}

		diff_eau <- false;
	}

	bool diffusion1 <- false;

	reflex valeurs_influences when: diff_eau = false and cycle < 2 {
		ask espace where (each.esp_forage = true) {
			influence_eau <- 1.1;
		}

		ask espace where (each.esp_infrast_marche = true) {
			influence_infras_marche <- 1.1;
		}

		ask espace where (each.esp_infrast_veto = true) {
			influence_infras_veto <- 1.1;
		}

		diffuse var: influence_infras_marche on: espace where (each.esp_infrast_marche = true) propagation: diffusion radius: int(9 #km / largeur_cellule);
		diffuse var: influence_infras_veto on: espace where (each.esp_infrast_veto = true) propagation: diffusion radius: int(4 #km / largeur_cellule);
		diffuse var: influence_eau on: espace where (each.esp_forage = true) propagation: diffusion radius: int(15 #km / largeur_cellule);
		diffusion1 <- true;
	}

	//------------- remontée FIT -------------------------------------------------------------------------------------------------
	reflex remonte_fit when: current_date >= f_cetcelde {
		ask troupeau {
			if self.fin_transhumance = false {
				ask espace overlapping (self.location) {
					if s_pluie != 0 { // retour en fonction du FIT
						myself.fin_transhumance <- true;
						myself.date_retour <- current_date;
						myself.speed <- gauss(vitesse_retour, 2) #km / #days;
						myself.en_zone_acc <- false;
					}

				}

			}

		}

	}

	//--------------------------------------------------------------
	reflex trp_veg_grille when: every(step) {
		s_cons_jour <- s_cons_jour + sum(troupeau collect (each.cons_jour));
		evolution_veg <- sum(espace collect (each.r));
		impt_trp_veg <- with_precision((s_cons_jour / sum(espace collect (each.r_init))) * 100, 10);
		//------------ comptage du nombre de trp dans la grille -----------------
		if is_batch_impact_espace {
			ask espace {
				s_nb_trp_total <- s_nb_trp_total + length(troupeau inside (self));
				if troupeau inside (self) != [] {
					s_nb_trp <- 1;
				}

			}

		}

	}

	//---------------------------- durée de la transhumance --------------------------------
	reflex update_comptage_trp {
		cpt_trp_retour <- sum(troupeau collect (each.presence_terr_orig));
	}

	reflex metric when: cpt_trp_retour >= nb_trp - 1 {
		pct <- (sum(troupeau collect (each.pct_trp)) / nb_trp * 100) with_precision (3);
		std_pct <- standard_deviation(troupeau collect (each.pct_trp)) with_precision (3);
		pcnt <- (sum(troupeau collect (each.pcnt_trp)) / nb_trp * 100) with_precision (3);
		std_pcnt <- standard_deviation(troupeau collect (each.pcnt_trp)) with_precision (3);
		//write '' + pcnt + ' ' + std_pcnt;
		if is_batch_impact_espace {
			//save [pct, std_pct, pcnt, std_pcnt, largeur_cellule, temp] rewrite: false to: "impact_espace_t_sa18_news.csv" type: csv;
			save [pct, std_pct, pcnt, std_pcnt,vitesse_aller, vitesse_retour, largeur_cellule, temp] rewrite: false to: "validation_espace_vitesse_t2_sa18_news.csv" type: csv;
		}

		if is_batch_vitesse {
			save [pct, std_pct, pcnt, std_pcnt, vitesse_aller, vitesse_retour] rewrite: false to: "vitesse.csv" type: csv;
		}

		if is_batch_veg {
			save [pct, std_pct, pcnt, std_pcnt, lambda1] rewrite: false to: "vegetation.csv" type: csv;
		}

		if is_batch_ws {
			save [pct, std_pct, pcnt, std_pcnt, lambda2] rewrite: false to: "water.csv" type: csv;
		}

		if is_batch_veg_ws {
			save [pct, std_pct, pcnt, std_pcnt, lambda1, lambda2] rewrite: false to: "vegetation_water.csv" type: csv;
		}

		if is_batch_impact_tout_parametre {
			save [pct, std_pct, pcnt, std_pcnt, vitesse_aller, vitesse_retour, lambda1, lambda2, largeur_cellule, temp] rewrite: false to: "impact_tout_parametre_t2_sa20_news.csv" type:
			csv;
		}

	}

	//-------------------------------------------
} // fin du global

//******************************************************
grid espace cell_width: largeur_cellule cell_height: hauteur_cellule neighbors: 8 {
	string e_pasto;
	float r; //<- qt_pluie != 0 ? (4.1 * qt_pluie - 515) * hauteur_cellule * largeur_cellule : 1.0; // quantité de végétation en fonction de l'équation de Boudhet 
	float r_init;
	// <- qt_pluie != 0 ? (4.1 * qt_pluie - 515) * hauteur_cellule * largeur_cellule : 1.0; //Afin de simuler le debut de la saison des pluies ou la vegetation est plus
	rgb color2;
	float influence_infras_marche <- 0.0;
	bool esp_infrast_marche <- false;
	float influence_infras_veto <- 0.0;
	bool esp_infrast_veto <- false;
	float influence_eau <- 0.0;
	bool esp_forage <- false;
	//--------------------------------pluie et microfaune------
	float pluie_fit;
	float s_pluie <- 0.0;
	float e <- 0.0;
	//---------------- voisin ----------
	list voisins <- largeur_cellule <= 20 #km ? self neighbors_at (20 #km / largeur_cellule) where (each.color != #white) : self neighbors_at 1;
	//----------------------- fonction doptimisation ----------
	bool test_bol;
	int alpha1 <- 100;
	int alpha2 <- 100;
	int beta3;
	int alpha4;
	float alpha5 <- 0.0;
	float cout_eau_cell <- gauss(cout_eau, 1000);
	float cou_completion <- 150.0;
	float cou_soin <- gauss(cou_soin_moy, 10000);
	float cou_vente <- gauss(cou_vente_moy, 5000);
	float cou_vol <- gauss(cou_vol_moy, 1000);
	//-------------------------------
	int s_nb_trp_total;
	int s_nb_trp;
	int s_nb_collier;
	bool enregistrement <- true;
	//----------------------------------
	init {
		test_bol <- true;
		s_nb_trp_total <- 0;
		s_nb_trp <- 0;
		s_nb_collier <- 0;
		location <- self.location;
		if grid_x < 0 { // traite les exception du cas ou il aurait des indices négatifs de colonnes ou de lignes
			r_init <- 1.0;
			r <- 1.0;
		}

		if grid_y < 0 { // traite les exception du cas ou il aurait des indices négatifs de colonnes ou de lignes
			r_init <- 1.0;
			r <- 1.0;
		}
		//---------------------- qualité du fourrage ----------------------
		if e_pasto = "P1" or "P2" {
			beta3 <- -100;
		} else if e_pasto = "P3" {
			beta3 <- 1;
		} else {
			beta3 <- 100;
		}

		if is_batch_veg or is_batch_veg_ws {
			r <- lambda1 * r;
		}

	}

	reflex def_vois when: length(voisins) = 0 {
		voisins <- largeur_cellule <= 20 #km ? self neighbors_at (20 #km / largeur_cellule) where (each.color != #white) : self neighbors_at 1;
	}
	//------------------------------- carte de densité -----------------

	/*reflex densite_retour when: cpt_trp_retour >= nb_trp - 1 and enregistrement and is_batch_impact_espace {
		save [grid_x, grid_y, s_nb_trp_total, s_nb_trp] to: 'espace_vitesse' + largeur_cellule / 1000 + '.csv' rewrite: false type: 'csv';
		enregistrement <- !enregistrement;
	}*/
	reflex densite_retour_et_surpaturage_localise when: cpt_trp_retour >= nb_trp - 1 and enregistrement and is_batch_espace_collier {
		save [grid_x, grid_y, s_nb_collier] to: 'cell_colliers' + largeur_cellule / 1000 + '.csv' rewrite: false type: 'csv';
		enregistrement <- !enregistrement;
	}
	//------------------------- diminution de la végétation ----------------
	reflex vegetation_microfaune when: self.e_pasto != "N" and self.color != #grey and r != 0 {
		if current_date.month = 1 {
			e <- 0.099 / 30;
		} else if 2 <= current_date.month and current_date.month <= 7 {
			e <- 0.031 / 30;
		} else if 10 <= current_date.month and current_date.month <= 12 {
			e <- 0.099 / 30;
		} else {
			e <- 0.0;
		}

		r <- r - e * r;
	}

	//-------------------------- processus d'optimisation -----------------------
	reflex var_optimisation_val_fixe when: test_bol {
	//dans ce reflex on fixe la valeur de certains indicateurs de présence de points d'eau ou d'infrastructure pastorale 
	//------ presence veterinaire
		if esp_infrast_veto {
			self.alpha4 <- -100;
			self.cou_soin <- cou_soin * 2; //si la cellule contient un véto le cout des soins est divisé par 2, cela permet une bonne minimisation car alpha4<0
		} else {
			self.alpha4 <- 0;
		}

		ask forage overlapping (self) {
		//myself.cout_eau_cell <- (3 / 4) * cout_eau;
			if myself.alpha1 = 1 {
				myself.alpha2 <- 0;
			} else {
				myself.alpha2 <- 4000; // on modifie alpha2 ici
			}

		}
		//dans la zone d'influence d'un forage le coût de l'eau est de 3/4 celui ailleurs
		self.cout_eau_cell <- cout_eau + self.influence_eau * cout_eau;
		//si la cellule est dans la zone d'influence d'un marché alors le prix de vente de l'animal est meilleur
		self.cou_vente <- cou_vente + (self.influence_infras_marche * cou_vente); // on modifie le prix de vente des animaux ici
		test_bol <- false;
	}

	//-----------------------------------------------------------------------
	reflex fit when: current_date >= f_cetcelde and current_date <= fin_sai_pluie {
	//d_cetcelde <= current_date
		if flip(0.01) {
			pluie_fit <- rnd(2.0, 10.0);
			s_pluie <- s_pluie + pluie_fit;
			if r <= 0 { //controle de saisie
				r <- abs(4.1 * pluie_fit - 515) * hauteur_cellule * largeur_cellule;
			} else {
				r <- r + abs(4.1 * pluie_fit - 515) * hauteur_cellule * largeur_cellule;
			}

		}

	}

	//------------------------
} //fin de la grille

//*************************************************************
species colliers {
	string collier;

	aspect asp_collier {
		draw shape color: #maroon;
		//draw polyline(shape.points) color: #cyan;
	}

}

//********************************************************************
species troupeau skills: [moving] {
	float step <- 1 #days;
	int eff_bovin;
	float acc_bovin <- gauss(acc_bovin_moy, 0.1);
	int eff_ovin;
	float acc_ovin <- gauss(acc_ovin_moy, 0.1);
	int eff_caprin;
	float acc_caprin <- gauss(acc_caprin_moy, 0.1);
	//-----------------------------
	string type_trp <- 'gros_rum';
	image_file trp_gros_noir <- image_file("../includes/trp_black.png");
	//image_file trp_rouge <- image_file("../includes/trp_red.png");
	image_file trp_petit_noir <- image_file("../includes/goat_maron.png");
	//-------------------------------------
	float com_bovin <- com_bovin_moy;
	float com_ovin <- com_ovin_moy;
	float com_caprin <- com_caprin_moy;
	float cons_jour <- 0.0;
	int presence_ter_acc <- 0;
	int presence_terr_orig <- 0;
	int j1 <- rnd(15, 30);
	int j2 <- rnd(1, 15);
	date date_dep <- flip(0.5) ? date([2020, 10, j1, rnd(7, 8), 0]) : date([2020, 11, j2, rnd(7, 8), 0]);
	point terr_orig;
	list<point> L_terr_acc <- [];
	point terr_acc;
	float speed <- gauss(vitesse_aller, 2) #km / #days; //Donnée Habibou 
	string objectif <- 'deplacement';
	point the_target;
	bool en_zone_acc <- false;
	bool fin_transhumance <- false;
	//-------------------- vétérinaire --------------------
	bool soin <- flip(0.7) ? true : false; // source Thebaud p.16
	int jour_veto_trp <- rnd(jour_veto);
	int k1 <- 0; //cpt le nb de jour chez le veterinaire
	//--------------------- reseau social ------------------
	bool res_soc_za <- flip(p_res_social);
	int k2 <- 0; // cpt le nb de jour chez l'élément de reseau social
	//	int i <- 0; // vu que la diffusion ne seffectue pas d'un trait, ce compteur permet de
	point pos_elmt_soc;
	//la position de l'élement de reseau social ou le troupeau est allé
	int jour_res_social_trp <- rnd(jour_res_soc);
	list<point> res_visited; // <- [{0, 0, 0}];
	//------------------- optimisation---------------
	float alpha3;
	int beta4;
	float alpha5;
	int a <- 1;
	//----------------------------déplacement--------------------------------
	bool bool_cycle_aller <- true;
	int cycle_aller_micro_bovin <- 0;
	int cycle_retour_micro_bovin <- 0;
	int cycle_aller_micro_peti_rum <- 0;
	int cycle_retour_micro_peti_rum <- 0;
	date date_retour;
	bool arrive_orig <- true;
	list<point> point_chemin <- [];
	list<point> Lp_collier;
	float pct_trp <- 0.0;
	float pcnt_trp <- 0.0;
	//----------------------- liaison de la topologie du trp et de la grille --
	espace my_cell <- one_of(espace);
	bool signal <- false;

	init {
		if self.name = 'troupeau0' {
			self.terr_orig <- {146370.73593279847, 203352.05041704723, 0.0};
			L_terr_acc <-
			[{146370.73593279847, 203352.05041704723, 0.0}, {194657.98902403095, 212389.91932447156, 0.0}, {198198.85504588185, 210883.60783990085, 0.0}, {258035.0087062736, 227453.03417017875, 0.0}, {291232.4952064959, 215402.54229361302, 0.0}, {291232.4952064959, 212389.91932447156, 0.0}];
			//, {327447.9350249203, 209377.29635533012, 0.0}, {354355.5287183948, 202849.94658885698, 0.0}, {306307.3214345447, 162681.64033363777, 0.0}, {282283.2177926196, 130546.99532946243, 0.0}, {202202.87231953605, 98412.35032528706, 0.0}];

		} else if self.name = 'troupeau1' {
			self.terr_orig <- {46778.276432131475, 137074.34509593557, 0.0};
			L_terr_acc <-
			[{46778.276432131475, 137074.34509593557, 0.0}, {67903.94965954569, 158162.70587992563, 0.0}, {110155.29611437413, 176238.4436947743, 0.0}, {122227.10938718224, 194314.1815096229, 0.0}];
			//, {197675.942342233, 206364.6733861887, 0.0}, {267088.8686608797, 203352.05041704723, 0.0}, {270106.8219790817, 200339.4274479058, 0.0}, {276142.7286154858, 197326.80447876436, 0.0}, {276142.7286154858, 176238.4436947743, 0.0}, {267088.8686608797, 158162.70587992563, 0.0}, {261052.96202447562, 131049.09915765267, 0.0}, {242945.24211526345, 76821.88571310673, 0.0}];

		} else if self.name = 'troupeau2' {
			self.terr_orig <- {113173.24943257614, 188288.93557134003, 0.0};
			L_terr_acc <-
			[{113173.24943257614, 188288.93557134003, 0.0}, {179179.7729960245, 197828.9083069546, 0.0}, {199199.85936429538, 193812.07768143268, 0.0}, {265266.14437958936, 187786.83174314979, 0.0}, {288214.5418882939, 185276.3126021986, 0.0}];
			//, {357358.5416736355, 203854.15424523747, 0.0}, {361362.55894728965, 173727.92455382308, 0.0}];
		} else if self.name = 'troupeau3' {
			self.terr_orig <- {89029.6228869599, 143099.59103421844, 0.0};
			L_terr_acc <-
			[{89029.6228869599, 143099.59103421844, 0.0}, {73073.31524418877, 131551.2029858429, 0.0}, {67067.2893337075, 121509.12642203811, 0.0}, {73073.31524418877, 115483.88048375523, 0.0}, {71071.30660736168, 111467.04985823331, 0.0}, {49049.21160226369, 135568.03361136484, 0.0}, {49049.21160226369, 139584.86423688673, 0.0}];
			//, {93093.40161245968, 145610.11017516963, 0.0}];
		} else if self.name = 'troupeau4' {
			self.terr_orig <- {104119.38947797005, 185276.3126021986, 0.0};
			L_terr_acc <- [{104119.38947797005, 185276.3126021986, 0.0}, {185604.12906942487, 173225.82072563283, 0.0}, {201201.8680011225, 177744.755179345, 0.0}];
			//, {227227.98027987467, 177744.755179345, 0.0}, {247248.06664814556, 179753.17049210597, 0.0}, {281282.21347420604, 181761.58580486692, 0.0}, {289290.24802151445, 185778.41643038884, 0.0}, {271272.1702900706, 163685.84799001826, 0.0}, {247248.06664814556, 93391.31204338465, 0.0}, {241242.04073766427, 75315.57422853602, 0.0}];

		} else if self.name = 'troupeau5' {
			self.terr_orig <- {92047.57620516192, 155150.08291078417, 0.0};
			L_terr_acc <-
			[{92047.57620516192, 155150.08291078417, 0.0}, {111111.47934390348, 177744.755179345, 0.0}, {239927.28879706142, 203352.05041704723, 0.0}, {275276.1875637248, 197828.9083069546, 0.0}];
			//, {277278.19620055193, 177744.755179345, 0.0}, {267088.8686608797, 139584.86423688673, 0.0}];
		} else if self.name = 'troupeau6' {
			self.terr_orig <- {58850.0897049396, 152137.45994164277, 0.0};
			L_terr_acc <- [{58850.0897049396, 152137.45994164277, 0.0}, {83083.35842832421, 175736.33986658405, 0.0}, {116191.20275077817, 185276.3126021986, 0.0}];
			//, {171171.73844871615, 177744.755179345, 0.0}, {181181.78163285158, 177744.755179345, 0.0}, {241242.04073766427, 139584.86423688673, 0.0}, {195195.8420906412, 71298.7436030141, 0.0}];

		} else if self.name = 'troupeau7' {
			self.terr_orig <- {49049.21160226369, 137576.44892412578, 0.0};
			L_terr_acc <-
			[{49049.21160226369, 137576.44892412578, 0.0}, {51051.22023909078, 149626.94080069155, 0.0}, {69069.2979705346, 151635.35611345252, 0.0}, {103103.44479659511, 155652.18673897441, 0.0}, {123123.53116486601, 181761.58580486692, 0.0}, {146370.73593279847, 176238.4436947743, 0.0}];
			// {169169.72981188906, 175736.33986658405, 0.0}, {191191.82481698706, 177744.755179345, 0.0}, {199199.85936429538, 177744.755179345, 0.0}, {211211.91118525795, 183770.0011176279, 0.0}, {213213.919822085, 201845.73893247652, 0.0}, {221221.9543693934, 189795.24705591076, 0.0}, {218801.61556964723, 185276.3126021986, 0.0}];

		} else {
			self.terr_orig <- {7544.883295505076, 167200.57478734996, 0.0};
			L_terr_acc <-
			[{7544.883295505076, 167200.57478734996, 0.0}, {49796.22975033351, 164187.9518182085, 0.0}, {107137.34279617207, 188288.93557134003, 0.0}, {167496.40916021267, 185276.3126021986, 0.0}, {200693.89566043502, 206364.6733861887, 0.0}, {215783.66225144517, 203352.05041704723, 0.0}];
			//, {291232.4952064959, 215402.54229361302, 0.0}, {327447.9350249203, 209377.29635533012, 0.0}, {354609.51488873863, 200339.4274479058, 0.0}, {282178.6352518899, 128036.47618851122, 0.0}];

		}

		my_cell.location <- terr_orig;
		location <- my_cell.location; //afin que la position du trp et la var cellule d'espace pointe à la meme adresse
		terr_acc <- L_terr_acc[0];
		the_target <- terr_acc;
		res_visited <- [terr_acc];
		cpt_trp_retour <- 0;
		cons_jour <- (self.eff_bovin * self.com_bovin + self.eff_ovin * self.com_ovin + self.eff_caprin * self.com_caprin);
		if self.type_trp = 'gros_rum' {
			eff_bovin <- poisson(110);
			eff_ovin <- poisson(30);
			eff_caprin <- poisson(20);
		} else {
			eff_bovin <- poisson(8);
			eff_ovin <- poisson(150);
			eff_caprin <- poisson(80);
		}
		// creation du réseau social
		loop i from: 0 to: 8 {
			if self.name = 'troupeau' + i and rs_exist {
				ask colliers where (each.name = 'colliers' + i) {
				//write i;
					myself.Lp_collier <- self.shape.points;
				}

				create res_social number: length(L_terr_acc) {
					location <- one_of(Lp_collier);
				}

			}

		} } // fin de l'init


	//---------------- Les effectifs d'animaux -----------------------
	reflex dynamique_population when: every(3 #month) {
		eff_bovin <- round(eff_bovin + (acc_bovin / 400) * eff_bovin);
		eff_ovin <- round(eff_ovin + (acc_ovin / 400) * eff_ovin);
		eff_caprin <- round(eff_caprin + (acc_caprin / 400) * eff_caprin);
		cons_jour <- (self.eff_bovin * self.com_bovin + self.eff_ovin * self.com_ovin + self.eff_caprin * self.com_caprin);
	}
	//----------------- trp broutte -------------
	reflex trp_broutte_et_chemin {
		my_cell.r <- my_cell.r - cons_jour;
		if my_cell.r <= cons_jour {
		//le transhumant estime qu'il doit se déplacer lors qu'il n'y a plus assez de pâturage 
		//le transhumant estime la quantité de biomasse à acheter
			self.signal <- true;
			self.alpha5 <- self.eff_bovin * self.com_bovin + self.eff_ovin * self.com_ovin + self.eff_caprin * self.com_caprin;
		} else {
			self.signal <- false;
			self.alpha5 <- 0.0;
		}

		if my_cell.r >= cons_jour {
			alpha3 <- 1.0;
		} else {
			alpha3 <- cons_jour / (my_cell.r + 10);
		}

		if point_chemin contains location = false {
			point_chemin <- point_chemin + [location];
		}

	}

	//---------------------- deplacement en lien avec le veterinaire ------------
	reflex chez_veterinaire when: my_cell.esp_infrast_veto and fin_transhumance = false and soin = false {
		the_target <- nil;
		k1 <- k1 + 1;
		soin <- true;
		beta4 <- 0;
		if k1 > jour_veto_trp {
			objectif <- 'quitter_veterinaire';
		}

	}

	reflex quitter_veterinaire when: objectif = 'quitter_veterinaire' {
		if self.location = position_efficiente {
			if fin_transhumance {
				the_target <- terr_orig;
			} else {
				the_target <- terr_acc;
			}

		} else {
			the_target <- position_efficiente;
		}

		k1 <- 0;
		objectif <- 'deplacement';
	}

	//-------------------------- deplacement en lien avec le R.S ------------
	//location overlaps (members closest_to (self)).location
	reflex chez_res_soc when: location != terr_acc and objectif = 'deplacement' and diffusion1 = true and rs_exist {
	//chez le réseau social différent de celui que le transhumant a éventuellement en zone d'accueil
		if members != [] {
			if self.location = one_of(members).location {
				the_target <- nil;
				k2 <- k2 + 1;
				if k2 > jour_res_social_trp {
					objectif <- 'quitter_res_soc';
				}

			}

		}

	}

	reflex quiter_res_social when: objectif = 'quitter_res_soc' and location != terr_acc and rs_exist {
		if self.location = position_efficiente {
			if fin_transhumance {
				the_target <- terr_orig;
			} else {
				the_target <- terr_acc;
			}

		} else {
			the_target <- position_efficiente;
		}

		k2 <- 0;
		objectif <- 'deplacement'; //factice permettant deviter certaines erreurs
	}
	//----------------------------------- deplacement lorsqu'il manque de la biomasse ----------------------------------------------
	reflex manque_bio_rs when: signal and en_zone_acc and fin_transhumance = false and objectif = 'recherche_bio' {
		ask my_cell neighbors_at (d_rech / largeur_cellule) where (each.r > self.cons_jour and each.color != #red) {
			myself.L1 <-
			myself.L1 + [self.alpha1 + self.alpha2 * self.cout_eau_cell + self.beta3 * myself.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
			myself.L2 <- myself.L2 + [self.location];
		}

		if L1 != [] {
			ind <- flip(0.5) ? L1 index_of (min(L1)) : L1 last_index_of (min(L1));
			pos_elmt_soc <- L2 at ind;
			the_target <- pos_elmt_soc;
			res_visited <- res_visited + [pos_elmt_soc];
			objectif <- 'aller_res_soc_manque_bio';
			do goto target: the_target;
		}

		L1 <- [];
		L2 <- [];
	}

	reflex quitter_rs_manque_bio when: objectif = 'aller_res_soc_manque_bio' and self.location = pos_elmt_soc and signal {
	// ce reflex evite que le troupeau aille plus d'une fois chez le meme element de rs sachant quil ny a plus de biomasse la bas
		objectif <- 'recherche_bio';
	}
	//-----------------------------------------------------------------------------------------------------
	point position1 <- nil;
	point position2 <- nil;

	//pour la validation on a pas besoin des mouvement journalier en terroir d'accueil
	reflex aller_za when: fin_transhumance = false and current_date >= date_dep and length(L_terr_acc) > 0 {
		do goto target: the_target;
		my_cell.location <- self.location;
		res_visited <- res_visited + [location];
		if cycle mod (2) != 0 {
			position1 <- self.location;
		} else {
			position2 <- self.location;
		}

		if position1 = position2 {

		//if location = terr_acc {
			remove L_terr_acc[0] from: L_terr_acc;
			if L_terr_acc != [] {
				terr_acc <- L_terr_acc[0];
				the_target <- terr_acc;
			} else {
				the_target <- nil;
				presence_terr_orig <- 1;
			}

		}

	}

	bool defi_vitess <- true;

	reflex fin_transhumance when: current_date > f_cetcelde and current_date < fin_transh_au_plus_tard and fin_transhumance = false {
	//ce reflex me permet de mettre fin à la transhumance de tt le monde à partir d'une certaine date, ca evite le cas du nomadisme
		fin_transhumance <- true;
		date_retour <- current_date;
		if defi_vitess {
			speed <- gauss(vitesse_retour, 2) #km / #day;
			defi_vitess <- false;
		}

	}

	/*reflex retour_co when: fin_transhumance and presence_terr_orig = 0 {
		if self.name = 'troupeau2' or self.name = 'troupeau3' or self.name = 'troupeau7' {
			presence_terr_orig <- 1;
			the_target <- nil; //la transhumance de ce troupeau n'est pas complete (trp2) ou le trp n'est pas retourné (trp3)
		}

		do goto target: the_target;
		my_cell.location <- self.location;
		if self.location = terr_orig and arrive_orig {
			presence_terr_orig <- 1;
			the_target <- nil;
			arrive_orig <- false;
		}

	}*/
	reflex volonte_vente when: every(nb_j_vente #days) {
	//inspiré de Corniaux 2018 p.5
		if a = 0 {
			a <- 1;
		}

	}
	//------------------------- optimisation----------
	list<float> L1 <- [];
	list<point> L2 <- [];
	int ind <- 0;
	point position_efficiente <- {0, 0, 0};

	reflex mecanisme_multi_objectif when: every(#day) {

	//---------------------------- fonction d'optimisation du choix du trajet --------------
		if fin_transhumance {
		//La phase retour de la transhumance
			ask my_cell.voisins where (each.location distance_to self.terr_orig < each.location distance_to self.location) {

			//le calcul de f se fait en fonction du troupeau le plus proche de la cellule
				if self.r - myself.cons_jour - myself.alpha5 <= 0 {
					myself.L1 <-
					myself.L1 + [self.alpha1 + self.alpha2 * self.cout_eau_cell + self.beta3 * myself.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin + alpha5 * self.cou_completion - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
					myself.L2 <- myself.L2 + [self.location];
				} else {
					myself.L1 <-
					myself.L1 + [self.alpha1 + self.alpha2 * self.cout_eau_cell + self.beta3 * myself.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
					myself.L2 <- myself.L2 + [self.location];
				}

			}

			if L1 != [] {
				ind <- flip(0.5) ? L1 index_of (min(L1)) : L1 last_index_of (min(L1));
				position_efficiente <- L2 at ind;
				the_target <- position_efficiente;
				res_visited <- res_visited + [position_efficiente];
			} else { // permet d'être sur que le troupeau retournera dans son campement d'origine
				the_target <- terr_orig;
			}

		} else {
		//La phase aller de la transhumance
			ask my_cell.voisins where (each.location distance_to self.terr_acc < each.location distance_to self.location) {
				if self.r - myself.cons_jour - myself.alpha5 <= 0 {
					myself.L1 <-
					myself.L1 + [self.alpha1 + self.alpha2 * self.cout_eau_cell + self.beta3 * myself.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin + alpha5 * self.cou_completion - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
					myself.L2 <- myself.L2 + [self.location];
				} else {
					myself.L1 <-
					myself.L1 + [self.alpha1 + self.alpha2 * self.cout_eau_cell + self.beta3 * myself.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
					myself.L2 <- myself.L2 + [self.location];
				}

			}

			//write L1;
			if L1 != [] {
				ind <- flip(0.5) ? L1 index_of (min(L1)) : L1 last_index_of (min(L1));
				if position_efficiente in res_visited = false {
					position_efficiente <- L2 at ind;
					the_target <- position_efficiente;
					res_visited <- res_visited + [position_efficiente];
				}

			} else {
				the_target <- terr_acc;
			}

		}

		L1 <- [];
		L2 <- [];
		if a = 1 {
			a <- 0;
		}

	}
	//---------------------------- Metric sur les distances ------------
	list cell_trp <- [];
	list<espace> cell_touch_trp <- [];
	list<espace> cell_collier <- [];
	list cell_col <- [];
	bool metriq <- true;

	reflex metric when: presence_terr_orig = 1 and metriq {
		cell_col <- agents_overlapping(polyline(Lp_collier));
		ask espace {
		//cellules touchées par les colliers
			if self in myself.cell_col {
				myself.cell_collier <- myself.cell_collier + [self];
				self.color <- #red;
				if is_batch_espace_collier {
					s_nb_collier <- 1;
				}

			}

		}

		//write cell_collier;
		cell_trp <- agents_overlapping(polyline(point_chemin));
		//cellules sur le chemin du trp
		ask espace {
			if self in myself.cell_trp {
				myself.cell_touch_trp <- myself.cell_touch_trp + [self];
				self.color <- #magenta;
			}

		}

		list<espace> cell_commune <- [];
		list<espace> cell_chemin_non_collier <- [];
		ask espace {
			if (self in myself.cell_collier) and (self in myself.cell_touch_trp) {
				cell_commune <- cell_commune + [self];
			}

			if (self in myself.cell_collier) = false and (self in myself.cell_touch_trp) {
				cell_chemin_non_collier <- cell_chemin_non_collier + [self];
			}

		}

		if length(cell_collier) != 0 {
			pct_trp <- length(cell_commune) / length(cell_collier);
			pcnt_trp <- length(cell_chemin_non_collier) / length(cell_collier);
			//1-pcnt donne la proportion des cellules du collier touchées par le troupeau et qui ne sont pas considérées comme mvt en terroir d'accueil

			//write 'compt' + name + ' ' + pcnt_trp;
			metriq <- false;
		}

	}

	//---------------------------- aspects -----------------------
	aspect asp_trp {
		if type_trp = 'gros_rum' {
			draw square(4000) color: #magenta;
		} else {
			draw square(4000) color: #black;
		}

	}

	rgb couleur_chemin <- one_of([#yellow, #green, #black, #magenta, #purple, #darkgoldenrod, #saddlebrown, #orange, #gold]);

	aspect chemin_trp {
		if name = 'troupeau8' {
			draw polyline(L_terr_acc) color: #cyan;
			draw polyline(point_chemin) color: couleur_chemin;
		}

	}

	aspect asp_trp_icone {
	/*if soin = false {
			draw trp_rouge size: 12000.0;
		} else {
			draw trp_noir size: 12000.0;
		}*/
		if type_trp = 'gros_rum' {
			draw trp_gros_noir size: 12200.0;
		} else {
			draw trp_petit_noir size: 12400.0;
		}

	}

	species res_social {
		espace rs_cell;
		bool eau_rs <- true;

		init {
			rs_cell <- location as espace;
		}

		reflex impt_social when: eau_rs and rs_exist {
			ask espace at_distance int(10 #km / largeur_cellule) {
				self.cout_eau_cell <- 2 / cout_eau;
				//c'est la quon agit pour supprimer l'impact du réseau social
				self.cou_vente <- 2 * cou_vente;
			}

			eau_rs <- false;
		}

	} } // fin du champ troupeau
//************************************************************
species vegetation {
	string pasto;
	rgb color_vegetation;

	/*aspect asp_vegetation_base {
		draw shape color: color_vegetation;
	}*/
}
//*********************************************
species marche_roi {
	image_file stars <- image_file("../includes/stars_gold_red.png");

	aspect marche {
		draw stars size: 10000.0;
	}

}

//*************************************************************
species infrast_pasto { // species vétérinaire
//string type;

//image_file veto <- image_file("../includes/veto_icone.png");
	aspect infrast_pasto {
	//draw veto size: 10000.0;
		draw square(3000) color: #maroon;
	}

}
//*************************************************************
species forage {
	float forage_debit;

	init {
		if flip(lambda2 / 2) and (is_batch_ws or is_batch_veg_ws) {
			do die;
		}

	}

	aspect asp_forage {
		draw triangle(6000) color: #blue;
	}

}

//*************************************************************
species hydro_ligne {
	point ref_1 <- {151313.04833475972, 125332.26743100787, 0.0}; // reference des isohyètes
	point ref_2 <- {99638.36295094644, 194236.32043985778, 0.0};
	bool water <- true;
	espace my_cell_h <- one_of(espace overlapping self);

	init {
		my_cell_h.location <- self.location;
		my_cell_h.alpha1 <- 1;
		if flip(lambda2) and (is_batch_ws or is_batch_veg_ws) {
		//write '1';
			do die;
		}

	}

	reflex dynamic when: every(#month) {

	// assèchement
		if self.location.y <= ref_1.y and current_date >= date([2020, 11, 30]) {
			water <- false;
		}

		if (ref_1.y <= self.location.y and self.location.y <= ref_2.y) and current_date >= date([2021, 1, 30]) {
			water <- false;
		}

		if ref_2.y <= self.location.y and current_date >= date([2020, 3, 30]) {
			water <- false;
		}
		//--------------- remplissage de l'eau -----------------
		if ref_2.y <= self.location.y and current_date >= date([2020, 6, 1]) {
			water <- true;
		}

		if (ref_1.y <= self.location.y and self.location.y <= ref_2.y) and current_date >= date([2021, 7, 1]) {
			water <- true;
		}

		if self.location.y <= ref_1.y and current_date >= date([2020, 8, 1]) {
			water <- true;
		}
		//----------------- Mise à jour de la valeur de alpha1: disponibilité du point d'eau de surface
		if self.water = true {
			my_cell_h.alpha1 <- 1;
		} else {
			my_cell_h.alpha1 <- 100;
		}

	}

	aspect eau_surface {
		draw shape color: #turquoise;
	}

}
//*************************************************************
experiment mecanism type: gui {
	output {
		monitor "Pluviométrie " value: plvt refresh: every(4 #days);
		display affichage_sig_zone type: opengl {
		//species vegetation;
			grid espace triangulation: true; // lines: #lightgrey;
			species forage aspect: asp_forage refresh: false;
			species hydro_ligne aspect: eau_surface refresh: false;
			species marche_roi aspect: marche refresh: false;
			species infrast_pasto aspect: infrast_pasto refresh: false;
			species troupeau aspect: asp_trp;
			//species troupeau aspect: asp_trp_icone;
		}

		display graphique type: java2D refresh: every(1 #week) {
			chart "Dynamic of herbivore population" type: series x_label: 'day' y_label: "size" size: {300 #px, 300 #px} position: {0, 0} {
				datalist ["Beef", "Sheep", "Goat"] value: [sum(troupeau collect (each.eff_bovin)), sum(troupeau collect (each.eff_ovin)), sum(troupeau collect (each.eff_caprin))] marker:
				false style: line thickness: 2 color: [#blue, #black, #maroon];
			}

			chart "(b) Vegetation gathered by herds" type: series x_label: 'day' y_label: "herds consommation (%)" size: {0.5, 0.5} position: {0.5, 0} {
				data "Vegetation gathered by herds" value: impt_trp_veg marker: false style: line thickness: 4 color: impt_trp_veg_color;
			}

			chart "(c) Evolution of vegetation" type: series x_label: 'day' y_label: "dry matter quantity (Kg/Ha)" size: {0.5, 0.5} position: {0, 0.5} {
				data "Evolution of vegetation" value: evolution_veg marker: false style: line thickness: 4 color: #green;
			}

			chart "Proportion of overgrazed cells" type: series x_label: 'day' y_label: "overgrazed cells (%)" size: {300 #px, 300 #px} position: {0, 0.5} {
				data "proportion" value: sous_seuil_veg marker: false style: line thickness: 4 color: #red;
			}

		}

	}

}

//*********************************** chemin mouvement ******************
experiment trace_chemin type: gui {
	output {
	//monitor "Pluviométrie " value: plvt refresh: every(1 #month);
		display marche_veto_forage_trp type: java2D {
			grid espace border: #lightgrey;
			species marche_roi aspect: marche refresh: false;
			species infrast_pasto aspect: infrast_pasto refresh: false;
			species forage aspect: asp_forage refresh: false;
			species colliers aspect: asp_collier refresh: false;
			//species troupeau aspect: chemin_trp;
		}

		display colliers type: java2D {
			grid espace border: #lightgrey;
			species colliers aspect: asp_collier refresh: false;
			//species troupeau aspect: chemin_trp;
			species troupeau aspect: asp_trp;
		}

	}

}
//--------------------------- batch pour déterminer le nombre efficient de replication  --------------
experiment nb_replication type: batch repeat: 35 until: cpt_trp_retour >= nb_trp or cycle >= 400 {
	parameter 'Batch' var: is_batch <- true;
	parameter 'dimension_espace' var: largeur_cellule <- 3 #km;

	reflex repli {
		save [mean(simulations collect (each.pct)), mean(simulations collect (each.std_pct)), mean(simulations collect (each.pcnt)), mean(simulations collect
		(each.std_pcnt)), largeur_cellule / 1000, simulation.nb_repliq] rewrite: false to: "nb_replication.csv" type: csv;
	}

}
//--------------------------- Batch cellules touchées par les colliers ----------------------------
experiment cellule_touch_colliers type: batch repeat: 1 until: cpt_trp_retour >= nb_trp or cycle >= 400 {
	parameter 'Batch_impact_espace' var: is_batch_espace_collier <- true;
	parameter 'dimension_espace' var: largeur_cellule <- 3 #km min: 27 #km step: 3 #km max: 36 #km;
}
//--------------------------- Batch dimension_impact_espace ---------------------------------
experiment impact_dimension_espace type: batch repeat: 18 until: cpt_trp_retour >= nb_trp or cycle >= 400 {
	parameter 'Batch_impact_espace' var: is_batch_impact_espace <- true;
	parameter 'dimension_espace' var: largeur_cellule <- 18 #km ;//min: 3 #km step: 3 #km max: 36 #km;
	parameter 'vitesse_aller' var: vitesse_aller <- 12.0 min: 12.0 step: 3 max: 22.0;
	parameter 'vitesse_retour' var: vitesse_retour <- vitesse_aller + 2.0  min: 14.0 step: 2 max: 30.0;

}
//----------------------------------------- Batch vitesse moyenne de déplacement des troupeaux ------
experiment impact_vitesse type: batch repeat: 35 until: cpt_trp_retour >= nb_trp or cycle >= 400 {
	parameter 'Batch_vitesse' var: is_batch_vitesse <- true;
	parameter 'vitesse_aller' var: vitesse_aller <- 12.0 min: 12.0 step: 3 max: 22.0;
	parameter 'vitesse_retour' var: vitesse_retour <- 32.0; //vitesse_aller + 2 min: 14.0 step: 2 max: 27.5;
}
//--------------------------------------- Batch impact de la quantité de végétation ----------------------------
experiment impact_quantite_veg type: batch repeat: 35 until: cpt_trp_retour >= nb_trp or cycle >= 400 {
	parameter 'Batch_veg' var: is_batch_veg <- true;
	parameter 'pourcentage_reduction' var: lambda1 among: [0.25, 0.5, 0.75] min: 0.25 max: 0.75;
}
//-------------------------------------- Batch impact de la réduction des points d'eaus -----------------------
experiment impact_nombre_ws type: batch repeat: 35 until: cpt_trp_retour >= nb_trp or cycle >= 400 {
	parameter 'Batch_veg' var: is_batch_ws <- true;
	parameter 'pourcentage_reduction' var: lambda2 among: [0.25, 0.5, 0.75] min: 0.25 max: 0.75;
}
//-------------------------------------- Batch impact de la réduction de la végétation et des points d'eaus ----------
experiment impact_quantite_veg_nombre_ws type: batch repeat: 35 until: cpt_trp_retour >= nb_trp or cycle >= 400 {
	parameter 'Batch_veg_ws' var: is_batch_veg_ws <- true;
	parameter 'pourcentage_reduction_veg' var: lambda1 <- 0.75 min: 0.25 max: 0.75;
	parameter 'pourcentage_reduction_ws' var: lambda2 among: [0.5, 0.75] min: 0.5 max: 0.75;
	method exhaustive;
}
//---------------------------------- Batch impact de tous les paramètres ---------------------------------------
experiment impact_tout_parametre type: batch repeat: 35 until: cpt_trp_retour >= nb_trp or cycle >= 400 {
	parameter 'Batch_impact_tout_parametre' var: is_batch_impact_tout_parametre <- true;
	parameter 'dimension_espace' var: largeur_cellule <- 3 #km min: 3 #km step: 3 #km max: 36 #km;
	parameter 'vitesse_aller' var: vitesse_aller <- 12.0 min: 12.0 step: 3 max: 22.0;
	parameter 'vitesse_retour' var: vitesse_retour <- vitesse_aller + 2 min: 14.0 step: 2 max: 30.0;
	parameter 'pourcentage_reduction_veg' var: lambda1 <- 0.25 min: 0.25 max: 0.75 step: 0.25;
	parameter 'pourcentage_reduction' var: lambda2 <- 0.5 min: 0.5 max: 0.75 step: 0.25;
}

