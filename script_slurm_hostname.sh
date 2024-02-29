#!/bin/bash
#SBATCH --job-name=script_slurm_hostname
#SBATCH --partition=debug
#SBATCH --nodelist=workernode
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --gres=gpu:1
#SBATCH --time=00:00:30
srun hostname
