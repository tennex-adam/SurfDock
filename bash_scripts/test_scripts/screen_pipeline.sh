#!/bin/bash

# Exit on any error
set -e

## Please set the GPU devices you want to use
gpu_string="0"

echo "Current conda environment: $CONDA_DEFAULT_ENV"

# Check GPU availability
echo "Checking GPU availability..."
nvidia-smi --list-gpus
echo "Available GPUs according to nvidia-smi:"
nvidia-smi -L

# Function to execute commands and check return codes
execute_command() {
    local cmd="$1"
    local description="$2"
    echo "=========================================="
    echo "Executing: $description"
    echo "Command: $cmd"
    echo "=========================================="
    eval "$cmd"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "ERROR: Command failed with exit code $exit_code"
        echo "Failed command: $cmd"
        exit $exit_code
    fi
    echo "SUCCESS: $description completed"
    echo "----------------------------------------"
}

# Function to validate GPU availability
validate_gpu() {
    local gpu_id="$1"
    echo "Validating GPU $gpu_id..."

    if ! command -v nvidia-smi &> /dev/null; then
        echo "ERROR: nvidia-smi not found. No GPU support available."
        exit 1
    fi

    local gpu_count=$(nvidia-smi --list-gpus | wc -l)
    echo "Total GPUs available: $gpu_count"

    if [ "$gpu_id" -ge "$gpu_count" ]; then
        echo "ERROR: GPU $gpu_id does not exist. Available GPUs: 0-$((gpu_count-1))"
        echo "Available GPUs:"
        nvidia-smi -L
        exit 1
    fi

    echo "GPU $gpu_id is available."
}

cat << 'EOF'
  ____  _     _ _   _ _   _ ____  _     _____ ____  _   _ ____  _     _     ____  _     ____  _        _ 
  ____              __ ____             _      ____       _         __     __            _             
 / ___| _   _ _ __ / _|  _ \  ___   ___| | __ | __ )  ___| |_ __ _  \ \   / /__ _ __ ___(_) ___  _ __  
 \___ \| | | | '__| |_| | | |/ _ \ / __| |/ / |  _ \ / _ \ __/ _` |  \ \ / / _ \ '__/ __| |/ _ \| '_ \ 
  ___) | |_| | |  |  _| |_| | (_) | (__|   <  | |_) |  __/ || (_| |   \ V /  __/ |  \__ \ | (_) | | | | 
 |____/ \__,_|_|  |_| |____/ \___/ \___|_|\_\ |____/ \___|\__\__,_|    \_/ \___|_|  |___/_|\___/|_| |_| 
                                                                                                       
                                                                                                       
  ____  _     _ _   _ _   _ ____  _     _____ ____  _   _ ____  _     _     ____  _     ____  _        _ 
EOF

path=$(readlink -f "$0")
SurfDockdir="$(dirname "$(dirname "$(dirname "$path")")")"
SurfDockdir=${SurfDockdir}
echo SurfDockdir : ${SurfDockdir}

temp="$(dirname "$(dirname "$(dirname "$(dirname "$path")")")")"
model_temp="$(dirname "$(dirname "$(dirname "$path")")")"

#------------------------------------------------------------------------------------------------#
#------------------------------------ Step1 : Setup Params --------------------------------------#
#------------------------------------------------------------------------------------------------#

export precomputed_arrays="${temp}/precomputed/precomputed_arrays"
echo "Using GPU devices: ${gpu_string}"
IFS=',' read -ra gpu_array <<< "$gpu_string"
NUM_GPUS=${#gpu_array[@]}

# Validate each GPU exists
for gpu_id in "${gpu_array[@]}"; do
    validate_gpu "$gpu_id"
done

export CUDA_VISIBLE_DEVICES=${gpu_string}
## Please set the main Parameters
main_process_port=2957${gpu_array[-1]}
## Please set the project name
project_name='SurfDock_Screen_samples_skip_target_processed'
# /home/caoduanhua/NM_submit_code/SurfDock
# Set default value for target_have_processed if not already set
target_have_processed=${target_have_processed:-true}
## Please set the path to save the surface file and pocket file
surface_out_dir=${temp}/Screen_result/processed_data/${project_name}/test_samples_8A_surface
## Please set the path to the input data
data_dir=${SurfDockdir}/data/Screen_sample_dirs/test_samples
## Please set the path to the output csv file
out_csv_dir=${temp}/Screen_result/processed_data/${project_name}/input_csv_files/
out_csv_file=${out_csv_dir}/test_samples.csv
## Please set the path to the esmbedding file
esmbedding_dir=${temp}/Screen_result/processed_data/${project_name}/test_samples_esmbedding
## Please set the path to the Screen ligand library file
Screen_lib_path=${SurfDockdir}/data/Screen_sample_dirs/test_samples/1a0q/1a0q_ligand_for_Screen.sdf
## Please set the path to the docking result directory
docking_out_dir=${temp}/Screen_result/docking_result/${project_name}
#------------------------------------------------------------------------------------------------#
# -----------------------Step1 : Processed Target Structure -------------------------------------#
#----------------(Set target_have_processed as true if you have done with your pipeline)---------#
#------------------------------------------------------------------------------------------------#
mkdir -p $surface_out_dir
if [ "$target_have_processed" = true ]; then
  echo "Target structure has been processed, skipping this step."
else
  echo "Processing target structure with OpenBabel..."
  export BABEL_LIBDIR=~/miniforge3/envs/SurfDock/lib/openbabel/3.1.0
  command="python ${SurfDockdir}/comp_surface/protein_process/openbabel_reduce_openbabel.py \
  --data_path ${data_dir} \
  --save_path ${surface_out_dir}"
  execute_command "$command" "Processing target structure with OpenBabel"
fi

#------------------------------------------------------------------------------------------------#
#----------------------------- Step2 : Compute Target Surface -----------------------------------#
#------------------------------------------------------------------------------------------------#
cd $surface_out_dir
command="python ${SurfDockdir}/comp_surface/prepare_target/computeTargetMesh_test_samples.py \
--data_dir ${data_dir} \
--out_dir ${surface_out_dir}"
execute_command "$command" "Computing target surface"

#------------------------------------------------------------------------------------------------#
#--------------------------------  Step3 : Get Input CSV File -----------------------------------#
#------------------------------------------------------------------------------------------------#
command="python ${SurfDockdir}/inference_utils/construct_csv_input.py \
--data_dir ${data_dir} \
--surface_out_dir ${surface_out_dir} \
--output_csv_file ${out_csv_file} \
--Screen_ligand_library_file ${Screen_lib_path}"
execute_command "$command" "Creating input CSV file"

#------------------------------------------------------------------------------------------------#
#--------------------------------  Step4 : Get Pocket ESM Embedding  ----------------------------#
#------------------------------------------------------------------------------------------------#
esm_dir=${SurfDockdir}/esm
sequence_out_file="${esmbedding_dir}/test_samples.fasta"
protein_pocket_csv=${out_csv_file}
full_protein_esm_embedding_dir="${esmbedding_dir}/esm_embedding_output"
pocket_emb_save_dir="${esmbedding_dir}/esm_embedding_pocket_output"
pocket_emb_save_to_single_file="${esmbedding_dir}/esm_embedding_pocket_output_for_train/esm2_3billion_pdbbind_embeddings.pt"
# get faste  sequence
command="python ${SurfDockdir}/datasets/esm_embedding_preparation.py \
--out_file ${sequence_out_file} \
--protein_ligand_csv ${protein_pocket_csv}"
execute_command "$command" "Generating FASTA sequence file"

command="python ${esm_dir}/scripts/extract.py \
\"esm2_t33_650M_UR50D\" \
${sequence_out_file} \
${full_protein_esm_embedding_dir} \
--repr_layers 33 \
--include \"per_tok\" \
--truncation_seq_length 4096"
execute_command "$command" "Extracting ESM embeddings"

# map pocket esm embedding
command="python ${SurfDockdir}/datasets/get_pocket_embedding.py \
--protein_pocket_csv ${protein_pocket_csv} \
--embeddings_dir ${full_protein_esm_embedding_dir} \
--pocket_emb_save_dir ${pocket_emb_save_dir}"
execute_command "$command" "Mapping pocket ESM embeddings"

# save pocket esm embedding to single file 
command="python ${SurfDockdir}/datasets/esm_pocket_embeddings_to_pt.py \
--esm_embeddings_path ${pocket_emb_save_dir} \
--output_path ${pocket_emb_save_to_single_file}"
execute_command "$command" "Saving pocket embeddings to single file"

#------------------------------------------------------------------------------------------------#
#------------------------  Step5 : Start Sampling Ligand Confromers  ----------------------------#
#------------------------------------------------------------------------------------------------#

diffusion_model_dir=${model_temp}/model_weights/docking
confidence_model_base_dir=${model_temp}/model_weights/posepredict
protein_embedding=${pocket_emb_save_to_single_file}
test_data_csv=${out_csv_file}
cd ${SurfDockdir}/bash_scripts/test_scripts
mdn_dist_threshold_test=3.0
version=6
dist_arrays=(3)
for i in ${dist_arrays[@]}
do
mdn_dist_threshold_test=${i}

command="accelerate launch \
--multi_gpu \
--main_process_port ${main_process_port} \
--num_processes ${NUM_GPUS} \
${SurfDockdir}/inference_accelerate.py \
--data_csv ${test_data_csv} \
--model_dir ${diffusion_model_dir} \
--ckpt best_ema_inference_epoch_model.pt \
--confidence_model_dir ${confidence_model_base_dir} \
--confidence_ckpt best_model.pt \
--save_docking_result \
--mdn_dist_threshold_test ${mdn_dist_threshold_test} \
--esm_embeddings_path ${protein_embedding} \
--run_name ${confidence_model_base_dir}_test_dist_${mdn_dist_threshold_test} \
--project ${project_name} \
--out_dir ${docking_out_dir} \
--batch_size 400 \
--batch_size_molecule 10 \
--samples_per_complex 40 \
--save_docking_result_number 40 \
--head_index  0 \
--tail_index 10000 \
--inference_mode Screen \
--wandb_dir ${temp}/docking_result/test_workdir"
execute_command "$command" "Running diffusion model inference for ligand conformer sampling"
done
#------------------------------------------------------------------------------------------------#
#---------------- Step6 : Start Rescoring the Pose For Screening  -----------------#
#------------------------------------------------------------------------------------------------#
out_csv_file=${out_csv_dir}/score_inplace.csv

command="python ${SurfDockdir}/inference_utils/construct_csv_input.py \
--data_dir ${data_dir} \
--surface_out_dir ${surface_out_dir} \
--output_csv_file ${out_csv_file} \
--Screen_ligand_library_file ${Screen_lib_path} \
--is_docking_result_dir \
--docking_result_dir ${docking_out_dir}"
execute_command "$command" "Creating CSV file for pose rescoring"

confidence_model_base_dir=${model_temp}/model_weights/screen
test_data_csv=${out_csv_file}

version=6
dist_arrays=(3)
for i in ${dist_arrays[@]}
do
mdn_dist_threshold_test=${i}
echo mdn_dist_threshold_test : ${mdn_dist_threshold_test}

# Check if GPUs are available for this step
if command -v nvidia-smi &> /dev/null && nvidia-smi > /dev/null 2>&1; then
    echo "GPUs detected, using accelerate with GPU support"
    command="accelerate launch \
    --main_process_port ${main_process_port} \
    --num_processes 1 \
    ${SurfDockdir}/evaluate_score_in_place.py \
    --data_csv ${test_data_csv} \
    --confidence_model_dir ${confidence_model_base_dir} \
    --confidence_ckpt best_model.pt \
    --model_version version6 \
    --mdn_dist_threshold_test ${mdn_dist_threshold_test} \
    --esm_embeddings_path ${protein_embedding} \
    --run_name ${project_name}_test_dist_${mdn_dist_threshold_test} \
    --project ${project_name} \
    --out_dir ${docking_out_dir} \
    --batch_size 40 \
    --wandb_dir ${temp}/wandb/test_workdir"
    execute_command "$command" "Running pose rescoring with GPU acceleration"
else
    echo "No GPUs detected, running without accelerate"
    command="python ${SurfDockdir}/evaluate_score_in_place.py \
    --data_csv ${test_data_csv} \
    --confidence_model_dir ${confidence_model_base_dir} \
    --confidence_ckpt best_model.pt \
    --model_version version6 \
    --mdn_dist_threshold_test ${mdn_dist_threshold_test} \
    --esm_embeddings_path ${protein_embedding} \
    --run_name ${project_name}_test_dist_${mdn_dist_threshold_test} \
    --project ${project_name} \
    --out_dir ${docking_out_dir} \
    --batch_size 40 \
    --wandb_dir ${temp}/wandb/test_workdir"
    execute_command "$command" "Running pose rescoring without GPU acceleration"
fi
done

cat << 'EOF'
  ____  _     _ _   _ _   _ ____  _     _____ ____  _   _ ____  _     _     ____  _     ____  _        _ 
  ____              __ ____             _      ____                        _ _               ____                   _  
 / ___| _   _ _ __ / _|  _ \  ___   ___| | __ / ___|  __ _ _ __ ___  _ __ | (_)_ __   __ _  |  _ \  ___  _ __   ___| | 
 \___ \| | | | '__| |_| | | |/ _ \ / __| |/ / \___ \ / _` | '_ ` _ \| '_ \| | | '_ \ / _` | | | | |/ _ \| '_ \ / _ \ | 
  ___) | |_| | |  |  _| |_| | (_) | (__|   <   ___) | (_| | | | | | | |_) | | | | | | (_| | | |_| | (_) | | | |  __/_| 
 |____/ \__,_|_|  |_| |____/ \___/ \___|_|\_\ |____/ \__,_|_| |_| |_| .__/|_|_|_| |_|\__, | |____/ \___/|_| |_|\___(_) 
                                                                    |_|              |___/                             
  ____  _     _ _   _ _   _ ____  _     _____ ____  _   _ ____  _     _     ____  _     ____  _        _ 
EOF