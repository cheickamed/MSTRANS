/**
* Name: mecaoptimisation
* Based on the internal empty template. 
* Author: Cheick Amed Diloma Gabriel TRAORE
* Tags: 
* Hypothèse de modèlisation
* Le troupeau ne peut pas consommer plus d'un tier de la biomasse d'une cellule car le reste sera dégradé naturellement ou consomé par la microfaune;
* Lorsque le pasteur n'est pas dans la zone d'influence de son réseau social, le coût de l'eau est doublé
* Le cout de vente des animaux est proportionnel à la distance du parcours du troupeau par rapport au marché. Plus il est proche du marché plus le prix est avantagieux
* Fait stylisés: évolution de la biomasse en fonction de l'impact de la microfaune
*/
model mecaoptimisation_image

global {
	file shape_file_forage <- file("../includes/forage_carre.shp");
	file shape_file_appetence <- file("../includes/morpho_pedo_carre.shp");
	file shape_file_hydro_line <- file("../includes/hydro_ligne_carre.shp");
	//file shape_file_zone <- file("../includes/zonage_transhumance.shp");
	file shape_file_zone <- file("../includes/zonage2.shp");
	file shape_file_infrastructure_pasto <- file("../includes/infrast_pasto.shp");
	file map_init <- image_file("../includes/ze_redim.png");
	//file map_init <- image_file("../includes/carte_coupe.png");
	geometry shape <- envelope(shape_file_appetence);

	//---------------------------------------les paramètres----------------------------------------
	date starting_date <- date([2020, 10, 15, 7, 0]);
	float step <- 1 #days;
	int nb_trp <- 200 min: 2 parameter: 'Nb_trp';
	int cpt_trp_aller;
	int cpt_trp_retour;
	int moy_cycle_aller <- 0;
	float std_cycle_aller_micro <- 0.0;
	int nb_cycle_aller;
	int nb_cycle_aller_retour;
	int nb_cycle_retour;
	bool is_batch <- false;

	//---------------------------------------------------------------------------
	/*int eff_bovin_moy <- 8 min: 0;// parameter: 'Bovin' category: "Effectif Ruminants";
	int eff_ovin_moy <- 220 min: 0;// parameter: 'Ovin' category: "Effectif Ruminants";
	int eff_caprin_moy <- 49 min: 0 ; //parameter: 'Caprin' category: "Effectif Ruminants";*/
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
	int jour_res_soc <- 4 min: 0 parameter: 'Nb jour' category: 'Reseau_social';
	float p_res_social <- 0.43 min: 0.0 parameter: 'accueil_ZA' category: 'Reseau_social';

	//---------------------------------- espace et vegetation ----------------
	float largeur_cellule <- 4 #km;
	float hauteur_cellule <- 4 #km;
	float impt_trp_veg <- 0.0;
	rgb impt_trp_veg_color <- #green;
	rgb veg_color <- #green;
	float evolution_veg <- sum(espace collect (each.r_init));
	float sous_seuil_veg <- 0.0;
	float r_g <- 0.0;
	float r_min <- 10 ^ 50;
	float q_seuil_r <- 0.33 min: 0.008 max: 0.9 parameter: "Sueil_biomasse" category: "Impact troupeau-végétation"; //le seuil de végétation, ce sueil(25%) est tiré de Dia et Duponnois:désertification
	float qt_pluie <- 150.0 min: 105.0 max: 700.0 parameter: 'Pluviométrie'; //rnd(100.0, 550.0) min: 50.0 max: 550.0 parameter: "Pluie(mm)" category: "Climat";
	string plvt;
	//interaction trp_veg
	float d_rech <- 30 #km min: 5 #km parameter: "dist-recherche-bio" category: "Impact troupeau-végétation";
	bool init_grille <- false;
	//------------------------------- paramètre d'optimisation ---------------
	float cout_eau <- 3250.0 parameter: "Eau" category: "Mecanisme optimisation"; // Ancey 2008
	float cou_soin_moy <- 89000.0 parameter: 'Soin' category: "Mecanisme optimisation";
	float cou_vente_moy <- 50000.0 parameter: 'vente' category: "Mecanisme optimisation";
	float cou_vol_moy <- 10000.0 parameter: 'Vol' category: "Mecanisme optimisation";
	//----------------- le calendrier pastoral ------------------------------
	date date_mj_pluie <- date([2021, 10, 10]);
	date date_mj_biomasse <- date([2021, 10, 1]);
	date d_cetcelde <- date([2021, 5, 15]);
	date f_cetcelde <- date([2021, 6, 30]);
	date fin_sai_pluie <- date([2021, 9, 30]);
	date fin_transh_au_plus_tard <- date([2021, 7, 1]);
	//------------------------- diffusion --------
	init {
		create forage from: shape_file_forage with: [forage_debit::float(get("Débit_expl"))];
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
				if
				polygon([{40326.01028006832, 4481.029275019886, 0.0}, {44771.060577107244, 35596.38135429192, 0.0}, {89777.19483462576, 39485.80036420096, 0.0}, {162009.2621615074, 33929.48749290244, 0.0}, {212016.07800319465, 66711.73343356396, 0.0}, {259244.73740923265, 96160.19165144651, 0.0}, {275913.67602312844, 122274.86214654986, 0.0}, {324253.5980034262, 108939.71125543327, 0.0}, {303139.60909249156, 61155.42056226544, 0.0}, {217572.39087449329, 12815.498581967782, 0.0}, {120336.91562676802, -2186.546170538524, 0.0}, {40326.01028006832, 4481.029275019886, 0.0}])
				overlaps (self) {
					self.en_zone_orig <- true;
				}

				if
				polygon([{0.0, 277584.84043412283, 0.0}, {16418.409398190677, 314330.80432531144, 0.0}, {81310.21797199198, 304948.8560977739, 0.0}, {106328.74657875876, 283057.6435668529, 0.0}, {129001.78812864108, 250220.82477047155, 0.0}, {59419.005441071, 225984.12518266635, 0.0}, {0.0, 277584.84043412283, 0.0}])
				overlaps (self) {
					self.en_zone_accueil <- true;
				}

			}

		}

		/*create bandi_contrainte number: 20 {
			status <- flip(0.6) ? 'voleur' : 'antagoniste';
		}*/
		create hydro_ligne from: shape_file_hydro_line;
		create zone from: shape_file_zone;
		create infrast_pasto from: shape_file_infrastructure_pasto with: [type:: string(get("type"))];
		create troupeau number: nb_trp;
		//initialisation de plvt
		if 450.0 <= qt_pluie and qt_pluie <= 550 {
			plvt <- 'bonne';
		} else if 300.0 <= qt_pluie and qt_pluie <= 449 {
			plvt <- 'moyenne';
		} else {
			plvt <- 'sécheresse';
		}

		//--------------- image raster ------------
		//map_init <- file(map_init as_matrix {87, 82});
		ask espace {
			color2 <- rgb(map_init at {grid_x, grid_y}); //prend la moyenne des elements vert contenue dans la cellule de grille
			//write (((color2 as list) at 0) / 255);
			//-------------------- initialisation de la vegetation ---------------------------------
			if self.e_pasto != "N" or self.e_pasto = "P1" or self.e_pasto = "P2" or self.e_pasto = "P3" or self.e_pasto = "P4" {
				r_init <- qt_pluie != 0 ? (4.1 * qt_pluie - 515) * hauteur_cellule * largeur_cellule * (((color2 as list) at 0) / 255) : 1;
				r <- r_init;
				seuil_r <- q_seuil_r * abs(r);
				if r_init = 0.0 { // resoud les exeption du cas ou il n'y a pas de vegetation dans un endroit à l'initialisation
					r_init <- 1.0;
				}

			} else {
				r_init <- 0.0;
				r <- r_init;
				seuil_r <- q_seuil_r * abs(r);
			}

		} } // fin de l'init
	reflex update_veg_color when: every(step) {
		ask espace {
			if e_pasto = "N" {
				self.color <- #red;
				self.r <- 0.0;
			} else if e_pasto = "P1" and r > seuil_r {
				self.color <- rgb(rgb(58, 137, 35), r / r_init);
			} else if e_pasto = "P2" and r > seuil_r {
				self.color <- rgb(rgb(1, 215, 88), r / r_init);
			} else if e_pasto = "P3" and r > seuil_r {
				self.color <- rgb(rgb(34, 120, 15), r / r_init);
			} else if e_pasto = "P4" and r > seuil_r {
				self.color <- rgb(rgb(176, 242, 182), r / r_init);
			} else {
				self.color <- #grey;
				self.r <- 0.0;
			} } }

			//----------------- debut operation de diffusion -----------
	bool diff_eau <- true;

	reflex var_dif_eau when: diff_eau {
		ask espace {
			ask forage inside self {
				myself.esp_forage <- true;
			}

			ask infrast_pasto inside self {
				if self.type = "marche" {
					myself.esp_infrast_marche <- true;
				} else {
					myself.esp_infrast_veto <- true;
				}

			}

		}

		diff_eau <- false;
	}

	bool diffusion1 <- false;

	reflex valeurs_influences when: diff_eau = false {
		ask espace where (each.esp_infrast_marche = true) {
			influence_infras_marche <- 1.1;
		}

		/*ask espace where (each.esp_infrast_veto = true) {
			influence_infras_veto <- 0.75;
		}*/
		ask espace where (each.esp_forage = true) {
			influence_eau <- 0.8;
		}

		diffuse var: influence_infras_marche on: espace where (each.esp_infrast_marche = true) propagation: diffusion radius: 2;
		//diffuse var: influence_infras_veto on: espace where (each.esp_infrast_veto = true) propagation: gradient; // radius: 4 #km;// valeur de ref pour déterminer celle des autres
		diffuse var: influence_eau on: espace where (each.esp_forage = true) propagation: diffusion radius: 4;
		diffusion1 <- true;
	}

	/*reflex diffusions when: diff_eau = false {
		diffuse var: influence_infras_marche on: espace where (each.esp_infrast_marche = true) propagation: diffusion radius: 2;
		//diffuse var: influence_infras_veto on: espace where (each.esp_infrast_veto = true) propagation: gradient; // radius: 4 #km;// valeur de ref pour déterminer celle des autres
		diffuse var: influence_eau on: espace where (each.esp_forage = true) propagation: diffusion radius: 4;
	}*/

//------------- remontée FIT -------------------------------------------------------------------------------------------------
	reflex remonte_fit when: current_date >= f_cetcelde {
		ask troupeau {
			if self.fin_transhumance = false {
				ask espace overlapping (self.location) {
					if s_pluie != 0 { // retour en fonction du FIT
						myself.fin_transhumance <- true;
						myself.en_zone_acc <- false;
						//myself.date_dep <- myself.date_dep add_days 365; //write myself.date_dep;

					}

				}

			}

		}

	}

	//--------------------------------------------------------------
	reflex trp_veg when: every(step) {
		s_cons_jour <- s_cons_jour + sum(troupeau collect (each.cons_jour));
		/*r_g <- sum(espace collect (each.r));
		//write r_g;
		if r_g <= r_min {
			r_min <- r_g;
		}*/
		evolution_veg <- sum(espace collect (each.r));
		sous_seuil_veg <- with_precision(sum(espace collect (each.surpature)) / length(espace where (each.e_pasto != "N")) * 100, 10);
		//write sous_seuil_veg;
		//evolution_veg <- with_precision((1 - r_min / sum(espace collect (each.r_init))) * 100, 10);
		impt_trp_veg <- with_precision((s_cons_jour / sum(espace collect (each.r_init))) * 100, 10);
	}

	//---------------------------- durée de la transhumance --------------------------------
	reflex update_comptage_trp {
		cpt_trp_aller <- sum(troupeau collect (each.presence_ter_acc));
		cpt_trp_retour <- sum(troupeau collect (each.presence_terr_orig));
	}

	reflex trp_dure_orig_acc when: cpt_trp_retour = nb_trp - 1 and is_batch {
		nb_cycle_aller <- round((current_date - starting_date) / 86400);
		//durée approximative de la phase aller de la transhumance
		moy_cycle_aller <- round(mean(troupeau collect (each.cycle_aller_micro)));
		std_cycle_aller_micro <- standard_deviation(troupeau collect (each.cycle_aller_micro));
		//write moy_cycle_aller;
		//do pause;
	}

	reflex remplissage_grille {
		ask espace {
			if length(troupeau inside (self)) != 0 {
				s_nb_trp_inside <- s_nb_trp_inside + length(troupeau inside (self));
			}

		}

	} } // fin du global

//******************************************************
grid espace cell_width: largeur_cellule cell_height: hauteur_cellule neighbors: 8 {
	string e_pasto;
	bool en_zone_orig <- false;
	bool en_zone_accueil <- false;
	float r; // <- 1.0; // quantité de végétation en fonction de l'équation de Boudhet 
	float r_init; // <- 4.8 * 10 ^ 8; //Afin de simuler le debut de la saison des pluies ou la vegetation est plus
	float seuil_r;
	int surpature <- 0;
	rgb color2;
	float influence_infras_marche <- 0.0;
	bool esp_infrast_marche <- false;
	//float influence_infras_veto <- 0.0;
	bool esp_infrast_veto <- false;
	float influence_eau <- 0.0;
	bool esp_forage <- false;
	//--------------------- carte de densité ------------------
	int s_nb_trp_inside;
	bool enregistrement <- true;
	bool enregistrement1 <- true;
	bool enregistrement2 <- true;

	//--------------------------------pluie et microfaune---------------------------------
	float pluie_fit;
	float s_pluie <- 0.0;
	float e <- 0.0;

	//------------------------ fonction doptimisation -----------------------
	bool test_bol;
	int alpha1 <- 100;
	int alpha2 <- 200;
	int beta3;
	int alpha4;
	float alpha5 <- 0.0;
	float cout_eau_cell <- gauss(cout_eau, 1000);
	float cou_completion <- 150.0;
	float cou_soin <- gauss(cou_soin_moy, 10000);
	float cou_vente <- gauss(cou_vente_moy, 5000);
	float cou_vol <- gauss(cou_vol_moy, 1000);

	init {
		test_bol <- true;
		s_nb_trp_inside <- 0;
		location <- self.location;
		//write location;
		//---------------------- qualité du fourrage ----------------------
		if e_pasto = "P1" or "P2" {
			beta3 <- -100;
		} else if e_pasto = "P3" {
			beta3 <- 1;
		} else {
			beta3 <- 100;
		}

		init_grille <- true;
	}

	//------------------------- diminution de la végétation ----------------
	reflex vegetation_microfaune when: self.e_pasto != "N" and self.color != #grey and r != 0 { //
		if current_date.month = 1 {
			e <- 0.092 / 30;
		} else if 2 <= current_date.month and current_date.month <= 7 {
			e <- 0.031 / 30;
		} else if 10 <= current_date.month and current_date.month <= 12 {
			e <- 0.099 / 30;
		} else {
			e <- 0.0;
		}

		r <- r - e * r;
	}

	reflex surpaturage when: every(3 #day) {
		if r < seuil_r {
			self.color <- #orange;
			surpature <- 1;
		} else {
			surpature <- 0;
		}

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
				myself.alpha2 <- 1;
			}

		}
		//dans la zone d'influence d'un forage le coût de l'eau est de 3/4 celui ailleurs
		self.cout_eau_cell <- cout_eau + self.influence_eau * cout_eau;
		//si la cellule est dans la zone d'influence d'un marché alors le prix de vente de l'animal est meilleur
		self.cou_vente <- cou_vente + self.influence_infras_marche * cou_vente;
		test_bol <- false;
	}

	//-----------------------------------------------------------------------
	reflex fit when: current_date >= f_cetcelde and current_date <= fin_sai_pluie { //d_cetcelde <= current_date
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

	//------------------------------- carte de densité -----------------
	reflex densite_aller when: cpt_trp_aller >= nb_trp and enregistrement {
		save [grid_x, grid_y, s_nb_trp_inside] to: 'eau_rs_ras_opt_aller_75r.csv' rewrite: false type: 'csv';
		s_nb_trp_inside <- 0;
		enregistrement <- false;
	}

	reflex densite_za when: cpt_trp_aller >= nb_trp and enregistrement1 and current_date > date([2021, 6, 15]) {
		save [grid_x, grid_y, s_nb_trp_inside] to: 'eau_rs_ras_opt_za_75r.csv' rewrite: false type: 'csv';
		s_nb_trp_inside <- 0;
		enregistrement1 <- false;
	}

	reflex densite_retour_et_surpaturage_localise when: cpt_trp_retour >= nb_trp - 1 and enregistrement2 {
		save [grid_x, grid_y, s_nb_trp_inside] to: 'eau_rs_ras_opt_retour_75r.csv' rewrite: false type: 'csv';
		save [grid_x, grid_y, surpature] to: 'trans_opt_surpaturage_0.33_200r.csv' rewrite: false type: 'csv';
		enregistrement2 <- !enregistrement2;
	} }
	//*************************************************************
species troupeau skills: [moving] {
	float step <- 1 #days;
	int eff_bovin;
	float acc_bovin <- gauss(acc_bovin_moy, 0.1);
	int eff_ovin;
	float acc_ovin <- gauss(acc_ovin_moy, 0.1);
	int eff_caprin;
	float acc_caprin <- gauss(acc_caprin_moy, 0.1);
	//-----------------------------
	string type_trp;
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
	point
	terr_orig <- any_location_in(polygon([{64794.08188692952, 31477.025629178388, 0.0}, {69702.86097971332, 33523.56217208016, 0.0}, {197571.02203684137, 64966.325043299, 0.0}, {249901.88101234683, 92196.61045416933, 0.0}, {301463.11581025284, 129504.565354791, 0.0}, {321880.7002303945, 94700.7261662092, 0.0}, {221963.3998252987, 22100.137802265817, 0.0}, {63909.11949671188, -10263.28950715647, 0.0}, {64794.08188692952, 31477.025629178388, 0.0}])).location;
	point terr_acc; // <- any_location_in(polygon([{0.0, 277584.84043412283, 0.0}, {16418.409398190677, 314330.80432531144, 0.0}, {81310.21797199198, 304948.8560977739, 0.0}, {106328.74657875876, 283057.6435668529, 0.0}, {129001.78812864108, 250220.82477047155, 0.0}, {59419.005441071, 225984.12518266635, 0.0}, {0.0, 277584.84043412283, 0.0}])).location;
	float speed <- gauss(19.6, 2) #km / #days; //Donnée Habibou 
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
	int i <- 0; // vu que la diffusion ne seffectue pas d'un trait, ce compteur permet de
	point pos_elmt_soc; //la position de l'élement de reseau social ou le troupeau est allé
	int jour_res_social_trp <- rnd(jour_res_soc);
	list<point> res_visited <- [{0, 0, 0}];
	//bool creation <- true;
	bool rs_manq_bio <- true;
	//------------------- optimisation---------------
	float alpha3;
	int beta4;
	float alpha5;
	int a <- 1;

	//----------------------------déplacement--------------------------------
	bool bool_cycle_aller <- true;
	int cycle_aller_micro <- 0;
	//----------------------- liaison de la topologie du trp et de la grille --
	espace my_cell <- one_of(espace inside
	polygon([{40326.01028006832, 4481.029275019886, 0.0}, {44771.060577107244, 35596.38135429192, 0.0}, {89777.19483462576, 39485.80036420096, 0.0}, {162009.2621615074, 33929.48749290244, 0.0}, {212016.07800319465, 66711.73343356396, 0.0}, {259244.73740923265, 96160.19165144651, 0.0}, {275913.67602312844, 122274.86214654986, 0.0}, {324253.5980034262, 108939.71125543327, 0.0}, {303139.60909249156, 61155.42056226544, 0.0}, {217572.39087449329, 12815.498581967782, 0.0}, {120336.91562676802, -2186.546170538524, 0.0}, {40326.01028006832, 4481.029275019886, 0.0}]));
	bool signal <- false;

	init {
		location <- my_cell.location;
		type_trp <- flip(0.32) ? 'gros_rum' : 'peti_rum';
		cpt_trp_aller <- 0;
		cpt_trp_retour <- 0;
		cons_jour <- (self.eff_bovin * self.com_bovin + self.eff_ovin * self.com_ovin + self.eff_caprin * self.com_caprin);
		if self.type_trp = 'gros_rum' {
			terr_acc <-
			any_location_in(polygon([{109976.39057523105, 122126.85505475942, 0.0}, {80349.39286259573, 142460.22999907122, 0.0}, {71403.05552267504, 175017.40473455004, 0.0}, {179194.4573483566, 178019.11325810337, 0.0}, {164280.68537360977, 141411.86862750398, 0.0}, {109976.39057523105, 122126.85505475942, 0.0}])).location;
			eff_bovin <- poisson(110);
			eff_ovin <- poisson(30);
			eff_caprin <- poisson(20);
		} else {
			terr_acc <-
			any_location_in(polygon([{39605.177417685045, 224815.27069711918, 0.0}, {36495.43742289889, 268573.4349335795, 0.0}, {66256.58758724772, 278825.4842998157, 0.0}, {161638.43687810237, 305287.4224984292, 0.0}, {192390.25212166528, 283837.68114104704, 0.0}, {133758.42919561738, 247311.8129288582, 0.0}, {39605.177417685045, 224815.27069711918, 0.0}])).location;
			eff_bovin <- poisson(8);
			eff_ovin <- poisson(150);
			eff_caprin <- poisson(80);
		}

	}

	reflex evolution_de_la_diffusion when: i <= 4 {
		i <- i + 1;
	}

	bool creation_rs <- false;

	reflex creation_rs_1 when: creation_rs = false and diffusion1 = true { //i > 1 and i < 4 and 
		if soin = false {
			beta4 <- 1;
		} else {
			beta4 <- 0;
		}
		//creation du premier element de rs
		// on ne cré pas de réseau social dans des cellules non pâturables
		if init_grille = true {
			create res_social number: 5 {
			//if one_of(espace where (each.color != #red and (each.location.y >= terr_orig.location.y + 10 #km and each.location.y < terr_orig.location.y + 20 #km) and (terr_orig.x - 50
			//#km < each.location.x and each.location.x < terr_orig.x + 50 #km) and (each.influence_eau != 0 or each.influence_infras_marche != 0))).location != {0, 0, 0} {
				self.location <- one_of(espace where (each.color != #red and (each.location.y >= terr_orig.location.y + 10 #km) and (terr_orig.x - 50 #km < each.location.x and
				each.location.x < terr_orig.x + 50 #km) and (each.influence_eau != 0 or each.influence_infras_marche != 0))).location;
				//} else {
				/*location <- one_of(espace where (each.color != #red and (each.location.y >= terr_orig.location.y + 10 #km and each.location.y < terr_orig.location.y + 20 #km) and
				(terr_orig.x - 50 #km < each.location.x and each.location.x < terr_orig.x + 50 #km))).location;*/ //}
				//Le transhumant na pas réussi à ce créer un élement de réseau social dans une zone judicieuse
			}

		}

		// création des autres éléments de rs
		/*float k <- 20 #km;
		loop while: k <= 110 #km {
			if init_grille = true {
				create res_social number: 1 {
					 one_of(espace where (each.color != #red and (each.location.y >= terr_orig.location.y + k and each.location.y < terr_orig.location.y + 20 #km + k) and (terr_orig.x - 50
					#km < each.location.x and each.location.x < terr_orig.x + 50 #km) and (each.influence_eau != 0 or each.influence_infras_marche != 0))).location != {0, 0, 0} {
						self.location <- one_of(espace where (each.color != #red and (each.location.y >= terr_orig.location.y + k and each.location.y < terr_orig.location.y + 20 #km + k) and
						(terr_orig.x - 50 #km < each.location.x and each.location.x < terr_orig.x + 50 #km) and (each.influence_eau != 0 or each.influence_infras_marche != 0))).location;
					} else {
					//location <- one_of(espace where (each.color != #red and (each.location.y >= terr_orig.location.y + k and each.location.y < terr_orig.location.y + 20 #km + k) and
					//(terr_orig.x - 50 #km < each.location.x and each.location.x < terr_orig.x + 50 #km))).location;
//Le transhumant na pas réussi à ce créer un élement de réseau social dans une zone judicieuse
			}

				}

			}

			k <- k + (20 + gauss(4, 1)) #km;
		}*/
// création du réseau social de chaque transhumant avec ou sans un hote en zone d'accueil
		if res_soc_za {
			create res_social {
				location <- terr_acc;
			}

		} else {
			create res_social {
				location <- one_of(espace where (each.en_zone_accueil = true)).location;
			}

		}

		creation_rs <- true;
	}

	//---------------- Les effectifs d'animaux -----------------------
	reflex dynamique_population when: every(3 #month) {
		eff_bovin <- round(eff_bovin + (acc_bovin / 400) * eff_bovin);
		eff_ovin <- round(eff_ovin + (acc_ovin / 400) * eff_ovin);
		eff_caprin <- round(eff_caprin + (acc_caprin / 400) * eff_caprin);
		cons_jour <- (self.eff_bovin * self.com_bovin + self.eff_ovin * self.com_ovin + self.eff_caprin * self.com_caprin);
	}
	//----------------- trp broutte -------------
	reflex trp_broutte {
		my_cell.r <- my_cell.r - cons_jour;
		if my_cell.r <= cons_jour {
		//le transhumant estime qu'il doit se déplacer lors qu'il n'y a plus assez de pâturage 
		//on peut changer cette condition en supposant que le transhumance va déplacer son troupeau sil ny a plus assez de pâturage pour trois jours par exemple 
		//le transhumant estime la quantité de biomasse à acheter
			self.signal <- true;
			self.alpha5 <- self.eff_bovin * self.com_bovin + self.eff_ovin * self.com_ovin + self.eff_caprin * self.com_caprin;
			my_cell.color <- #orange;
		} else {
			self.signal <- false;
			self.alpha5 <- 0.0;
		}

		if my_cell.r >= cons_jour {
			alpha3 <- 1.0;
		} else {
			alpha3 <- cons_jour / (my_cell.r + 10);
		}

	}

	//---------------------- deplacement en lien avec le veterinaire ------------
	reflex chez_veterinaire when: location distance_to (one_of(espace where (each.esp_infrast_veto))) <= largeur_cellule and fin_transhumance = false and soin = false {
		the_target <- nil;
		k1 <- k1 + 1;
		soin <- true;
		//write k1;
		beta4 <- 0;
		if k1 > jour_veto_trp {
			objectif <- 'quitter_veterinaire';
		}

	}

	reflex quitter_veterinaire when: objectif = 'quitter_veterinaire' {
	//the_target <- terr_acc;
		if self.location.y >= position_efficiente.y {
			the_target <- terr_acc;
		} else {
			the_target <- position_efficiente;
		}

		k1 <- 0;
		objectif <- 'deplacement';
	}

	//-------------------------- deplacement en lien avec le R.S ------------
	//location overlaps (members closest_to (self)).location
	reflex chez_res_soc when: self distance_to (members closest_to (self)) <= largeur_cellule and en_zone_acc = false and location != terr_acc and objectif = 'deplacement' and
	diffusion1 = true {
	//chez le réseau social différent de celui que le transhumant a éventuellement en zone d'accueil
		the_target <- nil;
		k2 <- k2 + 1;
		//write k2;
		//write self.name;
		if k2 > jour_res_social_trp {
			objectif <- 'quitter_res_soc';
		}

	}

	reflex quiter_res_social when: objectif = 'quitter_res_soc' and location != terr_acc and en_zone_acc = false {
	//write 'position_social';
		if self.location.y >= position_efficiente.y { //and (self.location.y >= position_efficiente.y) != nil
			the_target <- terr_acc;
		} else {
			the_target <- position_efficiente;
		}

		k2 <- 0;
		objectif <- 'deplacement'; //factice permettant deviter certaines erreurs
	}
	//----------------------------------- deplacement lorsqu'il manque de la biomasse ----------------------------------------------
	reflex manque_bio_rs when: signal and en_zone_acc and fin_transhumance = false and objectif = 'recherche_bio' {
		ask espace where (each.r > self.cons_jour and each.color != #red and each.location distance_to (self.location) <= d_rech) {
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
		} else {
		// sil ne trouve pas de cellule à 20 km
			ask espace where (each.r > self.cons_jour and each.color != #red and each.location distance_to (self.location) <= d_rech) {
				myself.L1 <-
				myself.L1 + [self.alpha1 + self.alpha2 * self.cout_eau_cell + self.beta3 * myself.alpha3 + myself.beta4 * self.alpha4 * self.cou_soin - myself.a * self.cou_vente + self.cou_soin + self.cou_vol];
				myself.L2 <- myself.L2 + [self.location];
			}

		}

		//write min(L1);
		L1 <- [];
		L2 <- [];
	}

	reflex quitter_rs_manque_bio when: objectif = 'aller_res_soc_manque_bio' and self.location = pos_elmt_soc and signal {
	// ce reflex evite que le troupeau aille plus d'une fois chez le meme element de rs sachant quil ny a plus de biomasse la bas
		objectif <- 'recherche_bio';
		ask self.res_social where (each.location = self.location) {
			do die; // tue l'élement de réseau social visité en le quittant, cette instruction vise l'optimisation du code
		}

		//write '1';
	}
	//-----------------------------------------------------------------------------------------------------
	//point position_social;
	reflex aller_za when: fin_transhumance = false and current_date >= date_dep {
		do goto target: the_target;
		//position_social <- members closest_to (self).location;
		if location = terr_acc { //and objectif != 'recherche_bio'
			the_target <- nil;
			en_zone_acc <- true;
			presence_ter_acc <- 1;
			objectif <- 'recherche_bio';
			//write '2';
			if bool_cycle_aller {
				cycle_aller_micro <- round((current_date - date_dep) / 86400);
				bool_cycle_aller <- !bool_cycle_aller;
			}
			// dès que le trp arrive en terr_ac il cré un nouveau elment de reseau social afin d'y aller lorsqu'il manque de la biomasse
			if rs_manq_bio and objectif != 'recherche_bio' { //sil ne manque pas de biomasse il n'est pas nécessaire d'avoir des relation social a dautres endroits
				create res_social number: rnd(1, 5) {
					location <- one_of(espace where (each.color != #red and (each.location.y >= terr_orig.location.y + 20 #km) and (terr_orig.x - 50 #km < each.location.x and
					each.location.x < terr_orig.x + 50 #km) and (each.influence_eau != 0 or each.influence_infras_marche != 0))).location;
				}

				rs_manq_bio <- false;
			}

		}

	}

	reflex fin_transhumance when: current_date > f_cetcelde and current_date < fin_transh_au_plus_tard and fin_transhumance = false {
	//ce reflex me permet de mettre fin à la transhumance de tt le monde à partir d'une certaine date, ca evite le cas du nomadisme
		fin_transhumance <- true;
	}

	reflex retour_co when: fin_transhumance {
		do goto target: the_target;
		if location = terr_orig {
			presence_terr_orig <- 1;
			nb_cycle_retour <- cycle - nb_cycle_aller;
			the_target <- nil;
		}

	}

	reflex volonte_vente when: every(1 #month) {
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

	reflex mecanisme_multi_objectif when: every(#day) and (presence_ter_acc = 0 or fin_transhumance) {

	//---------------------------- fonction d'optimisation du choix du trajet --------------
		if fin_transhumance {
		//La phase retour de la transhumance
			ask espace where (each.location.y < self.location.y - 14.5 #km and each.location.y > self.location.y - 20 #km and each.location.y > self.terr_orig.y and each.location
			distance_to (self.location) <= 20 #km) {
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

			//write length(L1);
			if L1 != [] {
				ind <- flip(0.5) ? L1 index_of (min(L1)) : L1 last_index_of (min(L1));
				position_efficiente <- L2 at ind;
				the_target <- position_efficiente;
			} else {
				the_target <- terr_orig;
			}

		} else {
		//La phase aller de la transhumance
			ask espace where (self.presence_ter_acc = 0 and each.location.y > self.location.y + 14.5 #km and each.location.y < self.location.y + 20 #km and each.location.y < self.terr_acc.y
			and each.location distance_to (self.location) <= 20 #km) {
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

			//write soin;
			if L1 != [] {
				ind <- flip(0.5) ? L1 index_of (min(L1)) : L1 last_index_of (min(L1));
				position_efficiente <- L2 at ind;
				the_target <- position_efficiente;
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
	//---------------------------- aspects -----------------------
	aspect asp_trp {
	/*if soin = false {
			draw square(4000) color: #red;
		} else {
			draw square(4000) color: #black;
		}*/
		if type_trp = 'gros_rum' {
			draw square(4000) color: #red;
		} else {
			draw square(4000) color: #black;
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

		reflex point_eau_social when: eau_rs {
			ask espace at_distance (10 #km) {
				self.cout_eau_cell <- 2 / cout_eau;
				//c'est la quon agit pour supprimer l'impact du réseau social
				self.cou_vente <- 2 * cou_vente;
			}

			eau_rs <- false;
		}

	}

} // fin du champ troupeau
//************************************************************
species vegetation {
	string pasto;
	rgb color_vegetation;

	/*aspect asp_vegetation_base {
		draw shape color: color_vegetation;
	}*/
}
//*************************************************************
species infrast_pasto {
	string type;
	image_file veto <- image_file("../includes/veto_icone.png");
	image_file marche <- image_file("../includes/marche_icone.png");

	aspect infrast_pasto {
		if type = 'marche' {
			draw marche size: 10000.0;
		} else {
			draw veto size: 10000.0;
		}

	}

}
//*************************************************************
species forage {
	float forage_debit;

	aspect asp_forage {
		draw square(3000) color: #blue;
	}

}

//*************************************************************
species hydro_ligne {
	point ref_1 <- {151313.04833475972, 125332.26743100787, 0.0};
	point ref_2 <- {99638.36295094644, 194236.32043985778, 0.0};
	bool water <- true;
	espace my_cell_h <- one_of(espace overlapping self);

	init {
		my_cell_h.location <- self.location;
		my_cell_h.alpha1 <- 1;
	}

	reflex dynamic when: every(#month) {

	// assèchement
		if self.location.y <= ref_1.y and current_date >= date([2020, 11, 30]) {
			water <- false;
		}

		if (ref_1.y <= self.location.y and self.location.y <= ref_2.y) and current_date >= date([2021, 1, 30]) {
			water <- false;
			//write 'fevrier';
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
			//write 'july';
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

		//write my_cell_h.alpha1;
	}

	aspect eau_surface {
		draw shape color: #turquoise;
	}

}
//*************************************************************
species zone schedules: [] {

	aspect asp_zone {
		draw shape color: #gamaorange;
	}

}
//*************************************************************
experiment mecanism type: gui {
	output {
		monitor "Pluviométrie " value: plvt refresh: every(1 #month);
		display affichage_sig_zone type: opengl {
			species vegetation;
			grid espace triangulation: true; // lines: #lightgrey;
			species forage aspect: asp_forage refresh: false;
			species zone aspect: asp_zone transparency: 0.3 refresh: false;
			species hydro_ligne aspect: eau_surface;
			//species bandi_contrainte aspect: asp_bandi;
			species infrast_pasto aspect: infrast_pasto refresh: false;
			species troupeau aspect: asp_trp;
		}

		display graphique type: java2D refresh: every(1 #week) {
			chart "Dynamic of herbivore population" type: series x_label: 'day' y_label: "size" size: {0.5, 0.5} position: {0, 0} {
				datalist ["Beef", "Sheep", "Goat"] value: [sum(troupeau collect (each.eff_bovin)), sum(troupeau collect (each.eff_ovin)), sum(troupeau collect (each.eff_caprin))] marker:
				false style: line thickness: 2 color: [#blue, #black, #maroon];
			}

			chart "Vegetation gathered by herds" type: series x_label: 'day' y_label: "herds consommation (%)" size: {0.5, 0.5} position: {0.5, 0} {
				data "Vegetation gathered by herds" value: impt_trp_veg marker: false style: line thickness: 4 color: impt_trp_veg_color;
			}

			chart "Evolution of vegetation" type: series x_label: 'day' y_label: "dry matter quantity (Kg/Ha)" size: {0.5, 0.5} position: {0, 0.5} {
				data "Evolution of vegetation" value: evolution_veg marker: false style: line thickness: 4 color: #green;
			}

			chart "Proportion of overgrazed cells" type: series x_label: 'day' y_label: "overgrazed cells (%)" size: {0.5, 0.5} position: {0.5, 0.5} {
				data "proportion" value: sous_seuil_veg marker: false style: line thickness: 4 color: #red;
			}

		}

	}

}

//------------------------------------
experiment multiple_rainfall type: gui {

	init {
	//create mecaoptimisation_image_model with: [qt_pluie::550];
		create mecaoptimisation_image_model with: [qt_pluie::375, q_seuil_r::0.4, impt_trp_veg_color::#orange, veg_color::#orange];
		create mecaoptimisation_image_model with: [qt_pluie::150, q_seuil_r::0.6, impt_trp_veg_color::#red, veg_color::#red];
	}

	permanent {
		display courbe_cumul type: java2D toolbar: #blue axes: false {
			chart "" type: series position: {0.5, 0} x_label: 'day' y_label: "herds size" size: {0.5, 0.5} {
				datalist ["Beef", "Sheep", "Goat"] value: [sum(troupeau collect (each.eff_bovin)), sum(troupeau collect (each.eff_ovin)), sum(troupeau collect (each.eff_caprin))] color:
				[#blue, #black, #maroon] marker: false;
			}

			chart "Evolution of vegetation" type: series x_label: 'day' y_label: "dry matter quantity (Kg/Ha)" position: {0, 0} size: {0.5, 1} {
				loop s over: simulations {
					data "Rainfall=" + s.qt_pluie value: s.evolution_veg color: s.veg_color marker: false;
				}

			}

			chart "Vegetation gathered by herds" type: series position: {0.5, 0.5} x_label: 'day' y_label: "herds consommation (%)" size: {0.5, 0.5} {
				loop s over: simulations {
					data "Rainfall=" + s.qt_pluie value: impt_trp_veg color: s.impt_trp_veg_color marker: false style: line thickness: 2 * (qt_pluie / 1000);
				}

			}

		}

	}

	output {
		layout #split editors: false consoles: false tabs: false tray: false parameters: false navigator: false;
		display graphique type: java2D toolbar: #green axes: false {
		/*chart "herds size" type: series size: {0.5, 0.5} position: {0, 0} {
				datalist ["Beef", "Sheep", "Goat"] value: [sum(troupeau collect (each.eff_bovin)), sum(troupeau collect (each.eff_ovin)), sum(troupeau collect (each.eff_caprin))] color:
				[#blue, #black, #maroon];
			}*/
			chart "Vegetation gathered by herds" type: series x_label: 'day' y_label: "herds consommation (%)" position: {0, 0.5} size: {1, 0.5} {
				data "Vegetation gathered by herds" value: impt_trp_veg color: impt_trp_veg_color;
			}

			chart "Evolution of vegetation" type: series x_label: 'day' y_label: "dry matter quantity (Kg/Ha)" size: {0.5, 0.5} position: {0.5, 0} {
				data "Evolution of vegetation" value: evolution_veg color: #green marker: false;
			}

		}

	}

}

//--------------------------------
experiment prop_cellule_degrade type: gui {

	init {
		create mecaoptimisation_image_model with: [q_seuil_r::0.8, veg_color::#orange];
		//create mecaoptimisation_image_model with: [q_seuil_r::0.6, veg_color::#red];
	}

	permanent {
		display courbe_evolution type: java2D toolbar: #red axes: false {
		/*chart "Evolution of vegetation" type: series x_label: 'day' y_label: "dry matter quantity (Kg/Ha)" position: {0, 0} size: {0.5, 1} {
				loop s over: simulations {
					data "Rainfall=" + s.qt_pluie value: s.evolution_veg color: s.veg_color marker: false style: line thickness: 4;
				}

			}*/
			chart "Proportion of overgrazed cells" type: series x_label: 'day' y_label: "overgrazed cells (%)" size: {0.5, 1} position: {0.5, 0} {
				loop s over: simulations {
					data "Theshold=" + s.q_seuil_r value: sous_seuil_veg color: s.veg_color marker: false style: line thickness: 2 * s.q_seuil_r;
				}

			}

		}

	}

	output {
		layout #split editors: false consoles: false tabs: false tray: false parameters: false navigator: false;
		display prp type: java2D toolbar: #green axes: false {
			chart "Evolution of vegetation" type: series x_label: 'day' y_label: "dry matter quantity (Kg/Ha)" size: {0.5, 1} position: {0, 0} {
				data "Rainfall=" + qt_pluie value: evolution_veg color: veg_color marker: false style: line thickness: 4;
			}

			chart "Proportion of overgrazed cells" type: series x_label: 'day' y_label: "overgrazed cells (%)" size: {0.5, 1} position: {0.5, 0} {
				data "Theshold=" + q_seuil_r value: sous_seuil_veg color: veg_color marker: false style: line thickness: 4;
			}

		}

	}

}
//*************************************************************************************************
experiment sauv_donne type: batch repeat: 75 until: cpt_trp_retour >= nb_trp {
	parameter 'Batch mode' var: is_batch <- true;
	//*************** sauvegarde du nombre de cycle moyen dans un fichier
	reflex save {
		save [round(simulations mean_of (each.nb_cycle_aller)), standard_deviation(simulations collect (each.nb_cycle_aller)), round(simulations mean_of
		(each.moy_cycle_aller)), std_cycle_aller_micro] to: "cycle_eau_rs_ras_opt_75r.txt" type: text;
		//round(simulations mean_of (each.nb_cycle_retour)), standard_deviation(simulations collect (each.nb_cycle_retour)), round(simulations mean_of (each.nb_cycle_aller_retour)), standard_deviation(simulations collect (each.nb_cycle_aller_retour)),

	}

}
