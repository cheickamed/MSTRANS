/**
* Name: carteTranshumantOptimisation
* Based on the internal empty template. 
* Author: Cheick Amed Diloma Gabriel Traoré
* Tags: 
*/
model carteTranshumantOptimisation

/* Insert your model definition here */
global {
	file shape_file_forage <- file("../includes/forage_carre.shp");
	file shape_file_appetence <- file("../includes/morpho_pedo_carre.shp");
	//file shape_file_hydro_poly <- file("../includes/decoupe/hydro_poly_carre.shp");
	file shape_file_hydro_line <- file("../includes/hydro_ligne_carre.shp");
	file shape_file_zone <- file("../includes/zonage_transhumance.shp");
	geometry shape <- envelope(shape_file_appetence);

	//---------------------------------------les paramètres----------------------------------------
	date starting_date <- date([2020, 10, 15, 7, 0]);
	float step <- 1 #day;
	int eff_bovin_moy <- 111 min: 0 parameter: 'Bovin' category: "Effectif Ruminants";
	int eff_ovin_moy <- 257 min: 0 parameter: 'Ovin' category: "Effectif Ruminants";
	int eff_caprin_moy <- 69 min: 0 parameter: 'Caprin' category: "Effectif Ruminants";
	float acc_bovin_moy <- 2.5 min: -10.0 max: 10.0 parameter: 'Bovin' category: "Accroissement (%) Ruminants";
	float acc_ovin_moy <- 2.5 min: -10.0 max: 25.0 parameter: 'Ovin' category: "Accroissement (%) Ruminants";
	float acc_caprin_moy <- 3.5 min: -10.0 max: 35.0 parameter: 'Caprin' category: "Accroissement (%) Ruminants";
	float com_bovin_moy <- 2.5 min: 2.0 max: 5.5 parameter: 'Bovin' category: "Consommation joulanlière biomasse";
	float com_ovin_moy <- 1.5 min: 2.0 max: 5.5 parameter: 'Ovin' category: "Consommation joulanlière biomasse";
	float com_caprin_moy <- 2.5 min: 2.0 max: 5.5 parameter: 'Caprin' category: "Consommation joulanlière biomasse";
	//interaction veto-perturbateur
	float dist_perturb <- 15.0 #km min: 0.0 parameter: 'dis_surete' category: 'Distance veterinaire/perturbateur (m)';
	float dist_veto <- 30.0 #km min: 0.0 parameter: 'dis_veto' category: 'Distance veterinaire/perturbateur (m)';
	//Réseau social
	float p_res_social <- 0.43 min: 0.0 parameter: 'accueil_ZA' category: 'Reseau_social';
	float dist_soc <- 5 #km min: 0.0 parameter: 'dis_soc (m)' category: 'Reseau_social';
	//interaction trp_veg
	float micro_faune <- 10.0 min: 0.0 max: 100.0 parameter: "Micro-faune" category: "Impact troupeau-végétation";
	float q_seuil_r <- 25.0 min: 0.0 max: 100.0 parameter: "Sueil_biomasse" category: "Impact troupeau-végétation";
	//le seuil de végétation, ce sueil(25%) est tiré de Dia et Duponnois:désertification
	float qt_pluie <- rnd(100.0, 550.0) min: 50.0 max: 550.0 parameter: "Pluie(mm)" category: "Climat";
	string plvt;
	//------------------------------- paramètre d'optimisation ---------------
	float cou_soin_moy <- 89000.0 parameter: 'Soin' category: "Mecanisme optimisation";
	float cou_completion_moy <- 65900.0 parameter: 'Achat aliment' category: "Mecanisme optimisation";
	float cou_vente_moy <- 50000.0 parameter: 'vente' category: "Mecanisme optimisation";
	float cou_vol_moy <- 10000.0 parameter: 'Vol' category: "Mecanisme optimisation";
	//----------------- le calendrier pastoral ------------------------------
	date date_mj_pluie <- date([2021, 10, 10]);
	date date_mj_biomasse <- date([2021, 10, 1]);
	date d_kawle <- date([2020, 10, 15]);
	date f_kawle <- date([2020, 11, 15]);
	date f_dabbunde <- date([2021, 1, 30]);
	date f_ceedu <- date([2021, 5, 30]);
	date d_cetcelde <- date([2021, 5, 15]);
	date f_cetcelde <- date([2021, 6, 30]);
	date fin_sai_pluie <- date([2021, 9, 30]);
	date fin_transh_au_plus_tard <- date([2021, 7, 15]);

	init {
		create forage from: shape_file_forage with: [forage_debit::float(get("Débit_expl"))];
		//create hydro_poly from: shape_file_hydro_poly;
		create hydro_line from: shape_file_hydro_line with: [long_eau::float(get("LENGTH"))];
		create vegetation from: shape_file_appetence with: [pasto::string(get("PASTORAL")), aire::float(get("AREA"))] {
			if pasto = "N" {
				color_vegetation <- rgb(165, 38, 10); //#red;
			} else if pasto = "P1" {
				color_vegetation <- rgb(58, 137, 35); // pâturage généralement de bonne qualité
			} else if pasto = "P2" {
				color_vegetation <- rgb(1, 215, 88); // pâturage généralement de qualité moyenne
			} else if pasto = "P3" {
				color_vegetation <- rgb(34, 120, 15); // pâturage généralement de qualité médiocre ou faible
			} else if pasto = "P4" {
				color_vegetation <- rgb(176, 242, 182); // pâturage uniquement exploitable en saison sèche, inondable
			} else {
				color_vegetation <- #white;
			} }

			//create roads from: shape_file_roads with: [sous_type::string(get("SOUSTYP"))];
		create zone from: shape_file_zone;
		//create zone_veto_insecu from: shape_insecu;
		create bandi_contrainte number: 20;
		create veterinaire number: 20;
		create troupeau number: 10 {
			location <- terr_orig;
		}

		//initialisation de plvt
		if 450.0 <= qt_pluie and qt_pluie <= 550 {
			plvt <- 'bonne';
		} else if 300.0 <= qt_pluie and qt_pluie <= 449 {
			plvt <- 'moyenne';
		} else {
			plvt <- 'sécheresse';
		} } //fin de l'init du champ global
	reflex position_veto {
		if length(veterinaire) != 0 {
			ask veterinaire {
				ask troupeau {
					if self.soin = false {
						if self distance_to myself <= dist_veto {
							self.objectif <- 'veterinaire';
							self.position_veto <- myself.location;
						}

					}

				}

			}

		}

	}
	//------------------------- Cas des voleurs --------------------
	reflex perturbation {
		if length(bandi_contrainte) != 0 {
			ask bandi_contrainte {
				ask troupeau {
					if self distance_to myself <= dist_perturb and self.objectif != 'deplacement_veto' {
						self.objectif <- 'arret_perturbation';
						//cette condition se repète avant et après la position du perturbateur. si le perturbateur arrete de se déplacer il me faudra revoir ce cas
					}

				}

			}

		}

	}
	//-------------- interaction trp_veg en zone d'accueil  ------------------
	reflex trp_arrive_za {
		ask troupeau inside
		polygon([{0.0, 277584.84043412283, 0.0}, {16418.409398190677, 314330.80432531144, 0.0}, {81310.21797199198, 304948.8560977739, 0.0}, {106328.74657875876, 283057.6435668529, 0.0}, {129001.78812864108, 250220.82477047155, 0.0}, {59419.005441071, 225984.12518266635, 0.0}, {0.0, 277584.84043412283, 0.0}])
		{
			if res_soc_za = false and choi_posi_za {
			//write self.terr_acc;
			//le trp na pas de reseau social en zone d'accueil
			//write res_soc_za;
				choi_posi_za <- false;
				//variable à mettre à jour si le modèle doit tourner plus d'une journée
				ask vegetation inside
				polygon([{0.0, 277584.84043412283, 0.0}, {16418.409398190677, 314330.80432531144, 0.0}, {81310.21797199198, 304948.8560977739, 0.0}, {106328.74657875876, 283057.6435668529, 0.0}, {129001.78812864108, 250220.82477047155, 0.0}, {59419.005441071, 225984.12518266635, 0.0}, {0.0, 277584.84043412283, 0.0}])
				{
					if (self.pasto = "P1" /*or self.pasto = "P3"*/) and r > q_seuil_r {
						myself.terr_acc <- one_of(self.location); //changement de l'emplacement du terroir d'accueil

					}

				}

				//write self.terr_acc;
				//write 'changement' + self.name;
			}

		}

	}

	//------------- remontée FIT -------------
	reflex remonte_fit when: d_cetcelde <= current_date and current_date <= f_cetcelde {
		ask troupeau {
			if self.fin_transhumance = false {
				ask vegetation overlapping (self.location) {
					if s_pluie != 0 { // retour en fonction du FIT
						myself.fin_transhumance <- true;
						myself.date_dep <- myself.date_dep add_days 365;
						//write myself.date_dep;
						//write 'fin transhumance ' + self.name;
					}

				}

			}

		}

	}

	//------------ mise à jour de la pluviométrie -----------------------
	reflex mis_j_pluiviometrie when: every(1 #year) and current_date >= date_mj_pluie {
	//Les bonnes ou mauvaises saison ne suiviennent pas au hasard
		if flip(0.9) {
			qt_pluie <- rnd(450.0, 550);
			plvt <- 'bonne';
		} else if flip(0.5) {
			qt_pluie <- rnd(300.0, 449);
			plvt <- 'moyenne';
		} else if flip(0.2) {
			qt_pluie <- rnd(100.0, 299);
			plvt <- 'sécheresse';
		} else {
			plvt <- 'bonne';
			qt_pluie <- rnd(450.0, 550);
		}

		//mise à jour des taux d'accroissement qui dépendent de la pluviométrie
		if qt_pluie >= 300.0 {
		//write 'mj';
			acc_bovin_moy <- gauss(acc_bovin_moy, 1);
			acc_ovin_moy <- gauss(acc_ovin_moy, 1);
			acc_caprin_moy <- gauss(acc_caprin_moy, 1);
		} else {
			acc_bovin_moy <- gauss(-acc_bovin_moy, 10);
			acc_ovin_moy <- gauss(-acc_ovin_moy, 10);
			acc_caprin_moy <- gauss(-acc_caprin_moy, 10);
		} }

		//--------------------mise à jour des couleurs
	reflex update_veg_color when: every(step) {
		ask vegetation {
			if pasto = "N" {
				color_vegetation <- rgb(rgb(165, 38, 10), r / r_init);
			} else if pasto = "P1" {
				color_vegetation <- rgb(rgb(58, 137, 35), r / r_init);
			} else if pasto = "P2" {
				color_vegetation <- rgb(rgb(1, 215, 88), r / r_init);
			} else if pasto = "P3" {
				color_vegetation <- rgb(rgb(34, 120, 15), r / r_init);
			} else if pasto = "P4" {
				color_vegetation <- rgb(rgb(176, 242, 182), r / r_init);
			} else {
				color_vegetation <- #white;
			} } }
			//---------interaction
	reflex mj_vegetation when: every(1 #year) and current_date >= date_mj_biomasse {
		ask vegetation {
		// on remet la biomasse à jour sans tenir compte de l'effet de la saison pluvieuse'
			r <- (4.1 * qt_pluie - 515) * aire;
			//write r;
			s_pluie <- 0.0;
		}

		date_mj_biomasse <- date_mj_biomasse add_days 365;
		//write date_mj_biomasse;
		date_mj_pluie <- date_mj_pluie add_days 365; //permet de mettre à jour la quantité de pluiviométrie
		fin_sai_pluie <- fin_sai_pluie add_days 365;
		d_cetcelde <- d_cetcelde add_days 365;
		f_cetcelde <- f_cetcelde add_days 365;
		fin_transh_au_plus_tard <- fin_transh_au_plus_tard add_days 365;
	}

	reflex trp_broutte when: every(step) {
		ask vegetation {
			ask troupeau inside self {
				if myself.ind_presence_bio {
					myself.r <- myself.r - (self.eff_bovin * self.com_bovin + self.eff_ovin * self.com_ovin + self.eff_caprin * self.com_caprin);
				} else {
					myself.color_vegetation <- #red;
				}

				if myself.r <= myself.seuil_r {
					myself.signal <- true;
					myself.color_vegetation <- #orange;
					self.alpha5 <- rnd(self.eff_bovin) * self.com_bovin + rnd(self.eff_ovin) * self.com_ovin + rnd(self.eff_caprin) * self.com_caprin;
				} else {
					self.alpha5 <- 0.0;
				}

			}

		}

	} }

species forage skills: [skill_road_node] {
	float forage_debit;

	aspect asp_forage {
		draw square(4000) color: #blue {
			if forage_debit = 0 {
				do die;
			}

		}

	}

}

//*****************************************************************
/*species hydro_poly schedules: [] {

	aspect asp_hydro_poly {
		draw shape color: #turquoise;
	}

}*/
//****************************************************************** hydroligne ****************************
species hydro_line {
	float long_eau;
	bool tari <- false;
	rgb hydro_color <- #turquoise;

	aspect asp_hydro_line {
		draw shape color: hydro_color;
	}

}

//********troupeau********************
species troupeau skills: [moving] {
	float step <- 1 #day;
	int eff_bovin <- poisson(eff_bovin_moy);
	float acc_bovin <- gauss(acc_bovin_moy, 1);
	int eff_ovin <- poisson(eff_ovin_moy);
	float acc_ovin <- gauss(acc_ovin_moy, 1);
	int eff_caprin <- poisson(eff_caprin_moy);
	float acc_caprin <- gauss(acc_caprin_moy, 1);
	float com_bovin <- gauss(com_bovin_moy, 1);
	float com_ovin <- gauss(com_ovin_moy, 1);
	float com_caprin <- gauss(com_caprin_moy, 1);
	int j1 <- rnd(15, 30);
	int j2 <- rnd(1, 15);
	date date_dep <- flip(0.5) ? date([2020, 10, j1, rnd(7, 8), 0]) : date([2020, 11, j2, rnd(7, 8), 0]);
	point
	terr_orig <- any_location_in(polygon([{40326.01028006832, 4481.029275019886, 0.0}, {44771.060577107244, 35596.38135429192, 0.0}, {89777.19483462576, 39485.80036420096, 0.0}, {162009.2621615074, 33929.48749290244, 0.0}, {212016.07800319465, 66711.73343356396, 0.0}, {259244.73740923265, 96160.19165144651, 0.0}, {275913.67602312844, 122274.86214654986, 0.0}, {324253.5980034262, 108939.71125543327, 0.0}, {303139.60909249156, 61155.42056226544, 0.0}, {217572.39087449329, 12815.498581967782, 0.0}, {120336.91562676802, -2186.546170538524, 0.0}, {40326.01028006832, 4481.029275019886, 0.0}])).location;
	//point

	//terr_acc <- any_location_in(polygon([{185532.50044891506, 275398.2942635843, 0.0}, {201950.90984710574, 312144.2581547729, 0.0}, {266842.71842090704, 302762.30992723536, 0.0}, {291861.2470276738, 280871.0973963144, 0.0}, {314534.28857755614, 248034.27859993302, 0.0}, {244951.50588998606, 223797.57901212783, 0.0}, {185532.50044891506, 275398.2942635843, 0.0}]));
	point
	terr_acc <- any_location_in(polygon([{0.0, 277584.84043412283, 0.0}, {16418.409398190677, 314330.80432531144, 0.0}, {81310.21797199198, 304948.8560977739, 0.0}, {106328.74657875876, 283057.6435668529, 0.0}, {129001.78812864108, 250220.82477047155, 0.0}, {59419.005441071, 225984.12518266635, 0.0}, {0.0, 277584.84043412283, 0.0}])).location;
	float speed <- gauss(12, 2) #km / #day;
	string objectif;
	int m <- rnd(1, 360);
	point the_target <- terr_acc; //a linitialisation il sait quil va au terroir d'accueil
	//point zone_installation;
	bool fin_transhumance <- false;
	bool soin <- flip(0.5) ? true : false;
	int jour_veto <- rnd(1, 4);
	int k1 <- 0;
	list<point> point_chemin_aller <- nil;
	list<point> point_chemin_retour <- nil;
	point ancienne_cible_veto;
	point position_veto;
	//interaction avec le perturbateur
	point modif_perturbation;
	int cpt_perturbation <- 0;
	//interaction social
	point position_social;
	bool res_soc_za <- flip(p_res_social);
	bool choi_posi_za <- !res_soc_za;
	float alpha5 <- 0.0;

	init {
		if res_soc_za { // création du réseau social de chaque transhumant avec ou sans un hote en zone d'accueil
			create res_social {
				location <- terr_acc; // le terroir d'accueil correspond à la position du lien social

				//any_location_in(polygon([{0.0, 277584.84043412283, 0.0}, {16418.409398190677, 314330.80432531144, 0.0}, {81310.21797199198, 304948.8560977739, 0.0}, {106328.74657875876, 283057.6435668529, 0.0}, {129001.78812864108, 250220.82477047155, 0.0}, {59419.005441071, 225984.12518266635, 0.0}, {0.0, 277584.84043412283, 0.0}])).location;

			}

			create res_social number: rnd(5, 9) {
				location <- any_location_in(world);
			}

		} else {
			create res_social number: rnd(5, 10) {
				location <- any_location_in(world);
				//write self.location = host.location;
			}

		}

	}

	//---------------------------------------------------------------- Les effectifs d'animaux --------------------------------
	reflex dynamique_population when: every(3 #month) {
		eff_bovin <- round(eff_bovin + (acc_bovin / 400) * eff_bovin);
		eff_ovin <- round(eff_ovin + (acc_ovin / 400) * eff_ovin);
		eff_caprin <- round(eff_caprin + (acc_caprin / 400) * eff_caprin);
	}
	//---------------------------------------------------------------- déplacement du troupeau --------------------------------
	reflex compt_jour {
		if m < 361 {
			m <- m + 1;
		} else {
			m <- 1;
			soin <- !soin; //je met à jour le carnet de vaccination du troupeau
		}

	}

	reflex dep_za when: fin_sai_pluie subtract_days 20 < current_date and current_date < date_mj_biomasse and fin_transhumance = true {
	//ce reflex permet daller en transhumance tout le temps 
	//write 'debut transhumance';
		fin_transhumance <- false;
	}

	reflex fin_transhumance when: current_date > f_cetcelde and current_date < fin_transh_au_plus_tard and fin_transhumance = false {
	//ce reflex me permet de mettre fin à la transhumance de tt le monde à partir d'une certaine date, ca evite le cas du nomadisme
		fin_transhumance <- true;
		//write 'fin transhumance';
	}

	reflex reseau_social when: members != [] {
		if self distance_to (members closest_to (self)) <= dist_soc {
			position_social <- the_target;
			//write the_target = position_social;
			the_target <- (members closest_to (self)).location;
			//write the_target = position_social;
			objectif <- 'quitter_res_soc';
		}

	}

	reflex quiter_res_social when: objectif = 'quitter_res_soc' and location != terr_acc {
	//write 'position_social';
		the_target <- position_social;
		objectif <- 'deplacement'; //factice permettant deviter certaines erreurs
	}

	reflex aller_veterinaire when: objectif = 'veterinaire' {
		ancienne_cible_veto <- the_target;
		//write ancienne_cible;
		the_target <- position_veto;
		//write the_target = ancienne_cible;
		objectif <- 'deplacement_veto';
	}

	reflex chez_veterinaire when: objectif = 'deplacement_veto' {
		if k1 = 0 {
			soin <- true;
		}

		if location = position_veto {
			the_target <- nil;
		}

		k1 <- k1 + 1;
		if k1 >= jour_veto {
		//		write "a";
			objectif <- 'quitter_veterinaire';
		}

	}

	reflex quitter_veterinaire when: objectif = 'quitter_veterinaire' {
		the_target <- ancienne_cible_veto;
		//write the_target = ancienne_cible;
		//write the_target;
		k1 <- 0;
		objectif <- 'deplacement';
	}

	reflex arret_perturbation when: objectif = 'arret_perturbation' {
		if cpt_perturbation = 0 { //controle evitant daffectezr à modif_perturbation une valeur null
			modif_perturbation <- the_target;
			the_target <- nil;
			//write 'perturbatuer';
		}

		cpt_perturbation <- cpt_perturbation + 1;
		if cpt_perturbation = 2 {
			objectif <- 'fin_perturbation';
		}

	}

	reflex reprise_chemin when: objectif = 'fin_perturbation' {
		cpt_perturbation <- 0;
		the_target <- modif_perturbation;
		objectif <- 'deplacement';
	}

	reflex aller_za when: fin_transhumance = false and current_date >= date_dep {
		the_target <- terr_acc;
		do goto target: the_target;
		if point_chemin_aller contains location = false {
		//write [location];
		//write point_chemin;
			point_chemin_aller <- point_chemin_aller + [location];
			//write '1' + point_chemin;
		}

		if location = terr_acc {
			the_target <- nil;
		}

	}

	reflex retour_co when: fin_transhumance {
		the_target <- terr_orig;
		do goto target: the_target;
		if point_chemin_retour contains location = false {
		//write [location];
		//write point_chemin;
			point_chemin_retour <- point_chemin_retour + [location];
			//write '1' + point_chemin;
		}

		if location = terr_orig {
			the_target <- nil;
		}

	}

	aspect asp_trp {
		draw circle(3000) color: #black;
	}

	aspect chemin_trp {
		draw polyline(point_chemin_aller) color: #black;
		draw polyline(point_chemin_retour) color: #red;
	}
	// sous species
	species res_social {

		init {
			self.location <- any_location_in(world);
		}

	}

}

//***************************
species vegetation {
	string pasto;
	float aire;
	rgb color_vegetation;
	float r <- qt_pluie != 0 ? (4.1 * qt_pluie - 515) * aire : 1; // quantité de végétation en fonction de l'équation de Boudhet 
	float r_init <- (4.1 * qt_pluie - 515) * aire;
	float seuil_r <- (q_seuil_r / 100) * r_init; //le seuil de végétation est le 10 de la végétation initiale
	bool ind_presence_bio <- r > 0 ? true : false;
	bool signal <- r > seuil_r ? false : true; // update: r > seuil_r ? false : true;
	//--------------- variable relative à la pluviométrie ------------

	//bool premiere_pluie <- false; // vas servir pour débuter le départ en terroir d'origine
	float pluie_fit;
	float s_pluie <- 0.0;
	//------------------------ fonction doptimisation -----------------------
	float alpha3;
	int beta3;
	int alpha4;
	int beta4;
	//float alpha5 <- 0.0;
	float cou_completion;
	float cou_soin <- gauss(cou_soin_moy, 10000);
	float cou_vente <- gauss(cou_vente_moy, 5000);
	float cou_vol <- gauss(cou_vol_moy, 1000);
	float f;
	float h;

	init {
	//---------------------- qualité du fourrage ----------------------
		if pasto = "P1" or "P2" {
			beta3 <- -100;
		} else if pasto = "P2" {
			beta3 <- 1;
		} else {
			beta3 <- 100;
		}

	}

	reflex mj_var_optimisation {
	//---------------- quantité du fourrage ------------------------
		if r >= seuil_r {
			alpha3 <- 1.0;
		} else {
			alpha3 <- seuil_r / r;
		}

		//---------------------- presence veterinaire ---------------------------
		if veterinaire overlapping self != [] {
			self.alpha4 <- -100;
		} else {
			self.alpha4 <- 0;
		}
		//--------------------------- decision de vacciner le troupeau -----------------
		ask troupeau inside self {
			if soin and myself.location distance_to (self) <= dist_veto {
				myself.beta4 <- 1;
			} else {
				myself.beta4 <- 0;
			}

		}

		//---------------------------- fonction d'optimisation du choix du trajet --------------

		//f <- beta3 * alpha3 + beta4 * alpha4 * beta4 * cou_soin + alpha5 * cou_completion;
		//g<-cou_vente;
		h <- cou_soin + cou_vol;
		//write f;
	}
	//-----------------------------------------------------------------------
	reflex fit when: d_cetcelde <= current_date and current_date <= fin_sai_pluie {
		if flip(0.01) {
		//write 'fit';
			pluie_fit <- rnd(2.0, 20);
			s_pluie <- s_pluie + pluie_fit;
			r <- r + abs(4.1 * pluie_fit - 515) * aire;
			//premiere_pluie <- true;
		}

	}

	reflex impact_micro_faune when: every(1 #month) { //détermine l'impact de la micro-faune sur la végétation à chaque pas de temps
		self.r <- (1 - micro_faune / 100) * self.r;
	}

	aspect asp_vegetation_base {
		draw shape color: color_vegetation;
		//draw string(f) color: #black;
	}

}
//***************************************************************
species zone {

	reflex assechement {
		if self.location = {186305.50298964034, 52669.41544973668, 0.0} {
			ask hydro_line {
				if myself.location distance_to self <= 50 #km and current_date <= f_kawle and self.hydro_color != #yellow {
					if flip(0.08) { //flip(1 - self.long_eau)
						self.tari <- true;
						self.hydro_color <- #yellow;
					}

				}

				if myself.location distance_to self <= 160 #km and current_date <= f_dabbunde and self.hydro_color != #yellow {
					if flip(0.09) { //flip(abs(0.4 - self.long_eau))
						self.tari <- true;
						self.hydro_color <- #yellow;
					}

				}

			}

		}

	}

	aspect asp_zone {
		draw shape color: #gamaorange;
	}

}

species veterinaire {

	aspect veto {
		draw square(6000) color: #yellow;
	}

}

species bandi_contrainte skills: [moving] {
//point

//location <- any_location_in(polygon([{-227093.6267222073, 1845400.1808777836, 0.0}, {-227093.85325360735, 1845400.223352421, 0.0}, {-227093.64088041979, 1845401.794914009, 0.0}, {-227092.7913876695, 1845402.1063946842, 0.0}, {-227092.2816920193, 1845402.0639200467, 0.0}, {-227091.64457245663, 1845401.7241229466, 0.0}, {-227091.5454649691, 1845400.7613644963, 0.0}, {-227092.4940652069, 1845400.1808777836, 0.0}, {-227093.6267222073, 1845400.1808777836, 0.0}, {-227093.6267222073, 1845400.1808777836, 0.0}]));
	string status <- flip(0.6) ? 'voleur' : 'antagoniste';

	reflex deplacement when: status = 'voleur' {
		do wander speed: 30 #km / #day;
	}

	aspect asp_bandi {
		if status = 'voleur' {
			draw triangle(6000) color: #red;
		} else {
			draw square(6000) color: #red;
		}

	}

}

//**************************************************************
experiment modele_RO {
	output {
		monitor "Pluviométrie " value: plvt refresh: every(1 #month);
		display affichage_sig_zone type: opengl {
			species vegetation aspect: asp_vegetation_base;
			species forage aspect: asp_forage refresh: false;
			species zone aspect: asp_zone transparency: 0.3;
			//species zone_veto_insecu aspect: asp_zone_veto_insecu transparency: 0.5;
			//species hydro_poly aspect: asp_hydro_poly;
			species hydro_line aspect: asp_hydro_line;
			species bandi_contrainte aspect: asp_bandi;
			species veterinaire aspect: veto refresh: false;
			species troupeau aspect: asp_trp;
		}

		display chemin_transhumants type: java2D {
			species troupeau aspect: chemin_trp;
		}

		/*display graphique type: java2D refresh: every(1 #week) {
			chart "Effectif hebdomadaire du troupeau" type: series size: {1, 0.5} position: {0, 0} {
				datalist ["Bovin", "Ovin", "Caprin"] value: [sum(troupeau collect (each.eff_bovin)), sum(troupeau collect (each.eff_ovin)), sum(troupeau collect (each.eff_caprin))] color:
				[#blue, #black, #maroon];
			}

			chart "Quantitté hebdomadaire de végétation" type: series size: {1, 0.5} position: {0, 0.5} {
				datalist ["Végétation"] value: [sum(vegetation collect (each.r))] color: [#blue];
				//ajouter le graphique de l'impact de la micro faune
			}

		}*/
	}

}